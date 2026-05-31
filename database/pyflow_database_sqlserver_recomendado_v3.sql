
-- ============================================================
--  PyFlow Manager — SQL Server DDL Script
--  Version : 3.0
--  Motor   : SQL Server 2016+ / Azure SQL Database
--
--  Plataforma para administrar scripts Python:
--    Ambientes, usuarios AD/Entra ID, scripts, versiones,
--    dependencias, parámetros, secretos cifrados, schedules,
--    ejecuciones, logs, archivos generados, notificaciones y auditoría.
--
--  IMPORTANTE:
--  Cambiar el password placeholder de CREATE MASTER KEY antes de producción.
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'PyFlowManager')
BEGIN
    CREATE DATABASE PyFlowManager COLLATE SQL_Latin1_General_CP1_CI_AS;
END
GO

USE PyFlowManager;
GO

-- ============================================================
--  0. Cifrado para secretos
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'CAMBIAR_ESTE_PASSWORD_EN_PRODUCCION_2026!';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'PyFlowSecretsCert')
BEGIN
    CREATE CERTIFICATE PyFlowSecretsCert
    WITH SUBJECT = 'PyFlow Manager - Secrets Encryption',
         EXPIRY_DATE = '2035-01-01';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'PyFlowSecretsKey')
BEGIN
    CREATE SYMMETRIC KEY PyFlowSecretsKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE PyFlowSecretsCert;
END
GO

-- ============================================================
--  1. Environments
-- ============================================================

IF OBJECT_ID('dbo.Environments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Environments (
        id              INT             NOT NULL IDENTITY(1,1),
        name            NVARCHAR(50)    NOT NULL,
        description     NVARCHAR(255)   NULL,
        is_active       BIT             NOT NULL CONSTRAINT DF_Environments_is_active DEFAULT 1,
        created_at      DATETIME2(0)    NOT NULL CONSTRAINT DF_Environments_created_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_Environments PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_Environments_name UNIQUE (name)
    );

    INSERT INTO dbo.Environments (name, description)
    VALUES
        ('Development', 'Ambiente local de desarrollo'),
        ('QA',          'Ambiente de pruebas y calidad'),
        ('Production',  'Ambiente productivo corporativo');
END
GO

-- ============================================================
--  2. Users
--  Compatible con login local, Active Directory o Entra ID.
-- ============================================================

IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        id                  INT             NOT NULL IDENTITY(1,1),
        username            NVARCHAR(100)   NOT NULL,
        email               NVARCHAR(255)   NOT NULL,
        display_name        NVARCHAR(255)   NULL,

        auth_provider       NVARCHAR(30)    NOT NULL CONSTRAINT DF_Users_auth_provider DEFAULT 'local',
            -- local | active_directory | entra_id

        azure_ad_object_id  NVARCHAR(100)   NULL,
        domain_user         NVARCHAR(150)   NULL,
        password_hash       NVARCHAR(512)   NULL,

        role                NVARCHAR(50)    NOT NULL CONSTRAINT DF_Users_role DEFAULT 'Viewer',
            -- Admin | DataArchitect | Developer | Operator | Viewer

        is_active           BIT             NOT NULL CONSTRAINT DF_Users_is_active DEFAULT 1,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_Users_created_at DEFAULT SYSUTCDATETIME(),
        updated_at          DATETIME2(0)    NULL,
        last_login          DATETIME2(0)    NULL,

        CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_Users_username UNIQUE (username),
        CONSTRAINT UQ_Users_email UNIQUE (email),
        CONSTRAINT CK_Users_role CHECK (role IN ('Admin', 'DataArchitect', 'Developer', 'Operator', 'Viewer')),
        CONSTRAINT CK_Users_auth_provider CHECK (auth_provider IN ('local', 'active_directory', 'entra_id')),
        CONSTRAINT CK_Users_password_provider CHECK (
               (auth_provider = 'local' AND password_hash IS NOT NULL)
            OR (auth_provider IN ('active_directory', 'entra_id'))
        )
    );

    CREATE NONCLUSTERED INDEX IX_Users_email ON dbo.Users (email);
    CREATE NONCLUSTERED INDEX IX_Users_is_active ON dbo.Users (is_active);
    CREATE NONCLUSTERED INDEX IX_Users_azure_ad_object_id ON dbo.Users (azure_ad_object_id);

    INSERT INTO dbo.Users (username, email, display_name, auth_provider, password_hash, role)
    VALUES ('Admin_User', 'admin@pyflow.local', 'Administrador PyFlow', 'local',
            '$2b$12$placeholder_hash_change_in_prod', 'Admin');
END
GO

-- ============================================================
--  3. Secrets
-- ============================================================

IF OBJECT_ID('dbo.Secrets', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Secrets (
        id                  INT             NOT NULL IDENTITY(1,1),
        secret_key          NVARCHAR(150)   NOT NULL,
        encrypted_value     VARBINARY(MAX)  NOT NULL,
        description         NVARCHAR(500)   NULL,
        updated_by_user_id  INT             NULL,
        updated_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_Secrets_updated_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_Secrets PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_Secrets_secret_key UNIQUE (secret_key),
        CONSTRAINT FK_Secrets_Users FOREIGN KEY (updated_by_user_id)
            REFERENCES dbo.Users (id) ON DELETE SET NULL
    );

    CREATE NONCLUSTERED INDEX IX_Secrets_secret_key ON dbo.Secrets (secret_key);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_InsertSecret
    @secret_key          NVARCHAR(150),
    @plain_value         NVARCHAR(MAX),
    @description         NVARCHAR(500) = NULL,
    @updated_by_user_id  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY PyFlowSecretsKey
    DECRYPTION BY CERTIFICATE PyFlowSecretsCert;

    MERGE dbo.Secrets AS target
    USING (SELECT @secret_key AS secret_key) AS source
        ON target.secret_key = source.secret_key
    WHEN MATCHED THEN
        UPDATE SET
            encrypted_value     = EncryptByKey(Key_GUID('PyFlowSecretsKey'), @plain_value),
            description         = COALESCE(@description, target.description),
            updated_by_user_id  = @updated_by_user_id,
            updated_at          = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (secret_key, encrypted_value, description, updated_by_user_id)
        VALUES (@secret_key, EncryptByKey(Key_GUID('PyFlowSecretsKey'), @plain_value), @description, @updated_by_user_id);

    CLOSE SYMMETRIC KEY PyFlowSecretsKey;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetSecret
    @secret_key NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY PyFlowSecretsKey
    DECRYPTION BY CERTIFICATE PyFlowSecretsCert;

    SELECT
        id,
        secret_key,
        CONVERT(NVARCHAR(MAX), DecryptByKey(encrypted_value)) AS plain_value,
        description,
        updated_by_user_id,
        updated_at
    FROM dbo.Secrets
    WHERE secret_key = @secret_key;

    CLOSE SYMMETRIC KEY PyFlowSecretsKey;
END
GO

-- ============================================================
--  4. Scripts
-- ============================================================

IF OBJECT_ID('dbo.Scripts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Scripts (
        id                  INT             NOT NULL IDENTITY(1,1),
        created_by_user_id  INT             NOT NULL,
        environment_id      INT             NOT NULL,

        name                NVARCHAR(255)   NOT NULL,
        description         NVARCHAR(1000)  NULL,
        category            NVARCHAR(100)   NOT NULL,

        current_version     NVARCHAR(30)    NOT NULL CONSTRAINT DF_Scripts_current_version DEFAULT '1.0.0',
        file_path           NVARCHAR(1000)  NOT NULL,
        working_directory   NVARCHAR(1000)  NULL,
        python_interpreter  NVARCHAR(1000)  NULL,

        author              NVARCHAR(255)   NULL,
        is_active           BIT             NOT NULL CONSTRAINT DF_Scripts_is_active DEFAULT 1,
        allow_manual_run    BIT             NOT NULL CONSTRAINT DF_Scripts_allow_manual_run DEFAULT 1,

        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_Scripts_created_at DEFAULT SYSUTCDATETIME(),
        updated_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_Scripts_updated_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_Scripts PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_Scripts_name_env UNIQUE (name, environment_id),
        CONSTRAINT FK_Scripts_Users FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users (id),
        CONSTRAINT FK_Scripts_Environments FOREIGN KEY (environment_id) REFERENCES dbo.Environments (id)
    );

    CREATE NONCLUSTERED INDEX IX_Scripts_category ON dbo.Scripts (category);
    CREATE NONCLUSTERED INDEX IX_Scripts_environment ON dbo.Scripts (environment_id);
    CREATE NONCLUSTERED INDEX IX_Scripts_is_active ON dbo.Scripts (is_active);
END
GO

-- ============================================================
--  5. ScriptVersions
-- ============================================================

IF OBJECT_ID('dbo.ScriptVersions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ScriptVersions (
        id                  INT             NOT NULL IDENTITY(1,1),
        script_id           INT             NOT NULL,
        version             NVARCHAR(30)    NOT NULL,
        file_path           NVARCHAR(1000)  NOT NULL,
        checksum_sha256     NVARCHAR(128)   NULL,
        change_notes        NVARCHAR(MAX)   NULL,
        created_by_user_id  INT             NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_ScriptVersions_created_at DEFAULT SYSUTCDATETIME(),
        is_current          BIT             NOT NULL CONSTRAINT DF_ScriptVersions_is_current DEFAULT 0,

        CONSTRAINT PK_ScriptVersions PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_ScriptVersions_script_version UNIQUE (script_id, version),
        CONSTRAINT FK_ScriptVersions_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts (id) ON DELETE CASCADE,
        CONSTRAINT FK_ScriptVersions_Users FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL
    );

    CREATE NONCLUSTERED INDEX IX_ScriptVersions_script_id ON dbo.ScriptVersions (script_id);
    CREATE NONCLUSTERED INDEX IX_ScriptVersions_is_current ON dbo.ScriptVersions (script_id, is_current);
END
GO

-- ============================================================
--  6. ScriptDependencies
-- ============================================================

IF OBJECT_ID('dbo.ScriptDependencies', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ScriptDependencies (
        id                    INT             NOT NULL IDENTITY(1,1),
        script_id             INT             NOT NULL,
        depends_on_script_id  INT             NOT NULL,
        execution_order       SMALLINT        NOT NULL CONSTRAINT DF_ScriptDependencies_order DEFAULT 1,
        dependency_type       NVARCHAR(20)    NOT NULL CONSTRAINT DF_ScriptDependencies_type DEFAULT 'hard',
        is_active             BIT             NOT NULL CONSTRAINT DF_ScriptDependencies_is_active DEFAULT 1,
        created_at            DATETIME2(0)    NOT NULL CONSTRAINT DF_ScriptDependencies_created_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_ScriptDependencies PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_ScriptDependencies UNIQUE (script_id, depends_on_script_id),
        CONSTRAINT FK_ScriptDep_Script FOREIGN KEY (script_id) REFERENCES dbo.Scripts (id) ON DELETE CASCADE,
        CONSTRAINT FK_ScriptDep_DependsOn FOREIGN KEY (depends_on_script_id) REFERENCES dbo.Scripts (id),
        CONSTRAINT CK_ScriptDependencies_no_self CHECK (script_id <> depends_on_script_id),
        CONSTRAINT CK_ScriptDependencies_type CHECK (dependency_type IN ('hard', 'soft'))
    );

    CREATE NONCLUSTERED INDEX IX_ScriptDep_script_id ON dbo.ScriptDependencies (script_id);
    CREATE NONCLUSTERED INDEX IX_ScriptDep_depends_on ON dbo.ScriptDependencies (depends_on_script_id);
END
GO

-- ============================================================
--  7. ScriptParameters
-- ============================================================

IF OBJECT_ID('dbo.ScriptParameters', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ScriptParameters (
        id              INT             NOT NULL IDENTITY(1,1),
        script_id       INT             NOT NULL,
        secret_id       INT             NULL,

        param_key       NVARCHAR(150)   NOT NULL,
        param_value     NVARCHAR(1000)  NULL,
        param_type      NVARCHAR(30)    NOT NULL CONSTRAINT DF_ScriptParameters_type DEFAULT 'env',
        is_secret       BIT             NOT NULL CONSTRAINT DF_ScriptParameters_is_secret DEFAULT 0,
        description     NVARCHAR(500)   NULL,
        created_at      DATETIME2(0)    NOT NULL CONSTRAINT DF_ScriptParameters_created_at DEFAULT SYSUTCDATETIME(),
        updated_at      DATETIME2(0)    NULL,

        CONSTRAINT PK_ScriptParameters PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_ScriptParameters_key UNIQUE (script_id, param_key),
        CONSTRAINT FK_ScriptParameters_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts (id) ON DELETE CASCADE,
        CONSTRAINT FK_ScriptParameters_Secrets FOREIGN KEY (secret_id) REFERENCES dbo.Secrets (id) ON DELETE SET NULL,
        CONSTRAINT CK_ScriptParameters_type CHECK (param_type IN ('env', 'argv', 'config')),
        CONSTRAINT CK_ScriptParameters_secret_consistency CHECK (
               (is_secret = 0 AND param_value IS NOT NULL)
            OR (is_secret = 1 AND secret_id IS NOT NULL)
        )
    );

    CREATE NONCLUSTERED INDEX IX_ScriptParameters_script_id ON dbo.ScriptParameters (script_id);
END
GO

-- ============================================================
--  8. GlobalEnvironmentVars
-- ============================================================

IF OBJECT_ID('dbo.GlobalEnvironmentVars', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GlobalEnvironmentVars (
        id                  INT             NOT NULL IDENTITY(1,1),
        environment_id      INT             NOT NULL,
        secret_id           INT             NULL,

        var_key             NVARCHAR(150)   NOT NULL,
        var_value           NVARCHAR(1000)  NULL,
        is_secret           BIT             NOT NULL CONSTRAINT DF_GlobalEnv_is_secret DEFAULT 0,

        description         NVARCHAR(500)   NULL,
        updated_by_user_id  INT             NULL,
        updated_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_GlobalEnv_updated_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_GlobalEnvironmentVars PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_GlobalEnvironmentVars_key_env UNIQUE (var_key, environment_id),
        CONSTRAINT FK_GlobalEnv_Environments FOREIGN KEY (environment_id) REFERENCES dbo.Environments (id),
        CONSTRAINT FK_GlobalEnv_Secrets FOREIGN KEY (secret_id) REFERENCES dbo.Secrets (id) ON DELETE SET NULL,
        CONSTRAINT FK_GlobalEnv_Users FOREIGN KEY (updated_by_user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL,
        CONSTRAINT CK_GlobalEnv_secret_consistency CHECK (
               (is_secret = 0 AND var_value IS NOT NULL)
            OR (is_secret = 1 AND secret_id IS NOT NULL)
        )
    );

    CREATE NONCLUSTERED INDEX IX_GlobalEnv_environment ON dbo.GlobalEnvironmentVars (environment_id);
END
GO

-- ============================================================
--  9. Schedules
-- ============================================================

IF OBJECT_ID('dbo.Schedules', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Schedules (
        id                    INT             NOT NULL IDENTITY(1,1),
        script_id             INT             NOT NULL,
        created_by_user_id    INT             NOT NULL,

        cron_expression       NVARCHAR(100)   NOT NULL,
        frequency_label       NVARCHAR(150)   NULL,
        timezone_name         NVARCHAR(100)   NOT NULL CONSTRAINT DF_Schedules_timezone DEFAULT 'America/Tegucigalpa',

        next_run_at           DATETIME2(0)    NULL,
        last_run_at           DATETIME2(0)    NULL,
        last_status           NVARCHAR(20)    NULL,
        last_error            NVARCHAR(MAX)   NULL,

        run_on_startup        BIT             NOT NULL CONSTRAINT DF_Schedules_run_on_startup DEFAULT 0,
        is_active             BIT             NOT NULL CONSTRAINT DF_Schedules_is_active DEFAULT 1,

        max_retries           SMALLINT        NOT NULL CONSTRAINT DF_Schedules_max_retries DEFAULT 3,
        retry_delay_seconds   INT             NOT NULL CONSTRAINT DF_Schedules_retry_delay DEFAULT 60,

        created_at            DATETIME2(0)    NOT NULL CONSTRAINT DF_Schedules_created_at DEFAULT SYSUTCDATETIME(),
        updated_at            DATETIME2(0)    NULL,

        CONSTRAINT PK_Schedules PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_Schedules_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts (id) ON DELETE CASCADE,
        CONSTRAINT FK_Schedules_Users FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users (id),
        CONSTRAINT CK_Schedules_status CHECK (
            last_status IS NULL OR last_status IN ('Exitoso', 'Error', 'Cancelado', 'Ejecutando')
        ),
        CONSTRAINT CK_Schedules_retries CHECK (max_retries BETWEEN 0 AND 10),
        CONSTRAINT CK_Schedules_retry_delay CHECK (retry_delay_seconds BETWEEN 0 AND 86400)
    );

    CREATE NONCLUSTERED INDEX IX_Schedules_script_id ON dbo.Schedules (script_id);
    CREATE NONCLUSTERED INDEX IX_Schedules_next_run ON dbo.Schedules (next_run_at) WHERE is_active = 1;
    CREATE NONCLUSTERED INDEX IX_Schedules_is_active ON dbo.Schedules (is_active);
END
GO

-- ============================================================
--  10. ScriptExecutions
-- ============================================================

IF OBJECT_ID('dbo.ScriptExecutions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ScriptExecutions (
        id                      INT             NOT NULL IDENTITY(1,1),
        script_id               INT             NOT NULL,
        script_version_id       INT             NULL,
        schedule_id             INT             NULL,
        triggered_by_user_id    INT             NULL,
        parent_execution_id     INT             NULL,

        status                  NVARCHAR(20)    NOT NULL CONSTRAINT DF_ScriptExecutions_status DEFAULT 'Ejecutando',
        trigger_type            NVARCHAR(20)    NOT NULL CONSTRAINT DF_ScriptExecutions_trigger DEFAULT 'manual',

        start_time              DATETIME2(3)    NOT NULL CONSTRAINT DF_ScriptExecutions_start_time DEFAULT SYSUTCDATETIME(),
        end_time                DATETIME2(3)    NULL,
        duration_seconds        INT             NULL,

        exit_code               INT             NULL,
        retry_attempt           SMALLINT        NOT NULL CONSTRAINT DF_ScriptExecutions_retry DEFAULT 0,

        process_id              INT             NULL,
        machine_name            NVARCHAR(255)   NULL,
        command_line            NVARCHAR(MAX)   NULL,
        working_directory       NVARCHAR(1000)  NULL,
        error_message           NVARCHAR(MAX)   NULL,

        CONSTRAINT PK_ScriptExecutions PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_Executions_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts (id),
        CONSTRAINT FK_Executions_ScriptVersions FOREIGN KEY (script_version_id) REFERENCES dbo.ScriptVersions (id),
        CONSTRAINT FK_Executions_Schedules FOREIGN KEY (schedule_id) REFERENCES dbo.Schedules (id) ON DELETE SET NULL,
        CONSTRAINT FK_Executions_Users FOREIGN KEY (triggered_by_user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL,
        CONSTRAINT FK_Executions_Parent FOREIGN KEY (parent_execution_id) REFERENCES dbo.ScriptExecutions (id),
        CONSTRAINT CK_Executions_status CHECK (status IN ('Ejecutando', 'Exitoso', 'Error', 'Cancelado')),
        CONSTRAINT CK_Executions_trigger CHECK (trigger_type IN ('manual', 'schedule', 'dependency', 'api', 'system'))
    );

    CREATE NONCLUSTERED INDEX IX_Executions_script_id ON dbo.ScriptExecutions (script_id);
    CREATE NONCLUSTERED INDEX IX_Executions_status ON dbo.ScriptExecutions (status);
    CREATE NONCLUSTERED INDEX IX_Executions_start_time ON dbo.ScriptExecutions (start_time DESC);
    CREATE NONCLUSTERED INDEX IX_Executions_schedule_id ON dbo.ScriptExecutions (schedule_id);
END
GO

CREATE OR ALTER TRIGGER dbo.trg_ScriptExecutions_CalcDuration
ON dbo.ScriptExecutions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ex
    SET duration_seconds = DATEDIFF(SECOND, ex.start_time, ex.end_time)
    FROM dbo.ScriptExecutions ex
    INNER JOIN inserted i ON i.id = ex.id
    WHERE i.end_time IS NOT NULL
      AND ex.duration_seconds IS NULL;
END
GO

-- ============================================================
--  11. ExecutionLogs
-- ============================================================

IF OBJECT_ID('dbo.ExecutionLogs', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExecutionLogs (
        id              BIGINT          NOT NULL IDENTITY(1,1),
        execution_id    INT             NOT NULL,

        log_level       NVARCHAR(10)    NOT NULL CONSTRAINT DF_ExecutionLogs_level DEFAULT 'INFO',
        message         NVARCHAR(MAX)   NOT NULL,
        logged_at       DATETIME2(3)    NOT NULL CONSTRAINT DF_ExecutionLogs_logged_at DEFAULT SYSUTCDATETIME(),
        line_number     INT             NULL,
        source          NVARCHAR(100)   NULL,

        CONSTRAINT PK_ExecutionLogs PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_ExecutionLogs_Executions FOREIGN KEY (execution_id)
            REFERENCES dbo.ScriptExecutions (id) ON DELETE CASCADE,
        CONSTRAINT CK_ExecutionLogs_level CHECK (
            log_level IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')
        )
    );

    CREATE NONCLUSTERED INDEX IX_ExecutionLogs_execution_id ON dbo.ExecutionLogs (execution_id, logged_at ASC);
    CREATE NONCLUSTERED INDEX IX_ExecutionLogs_level ON dbo.ExecutionLogs (log_level);
END
GO

-- ============================================================
--  12. ExecutionFiles
-- ============================================================

IF OBJECT_ID('dbo.ExecutionFiles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExecutionFiles (
        id                  INT             NOT NULL IDENTITY(1,1),
        execution_id        INT             NOT NULL,

        file_name           NVARCHAR(255)   NOT NULL,
        file_path           NVARCHAR(1000)  NOT NULL,
        file_type           NVARCHAR(30)    NOT NULL,
        mime_type           NVARCHAR(150)   NULL,
        file_size_bytes     BIGINT          NULL,
        checksum_sha256     NVARCHAR(128)   NULL,

        is_deleted          BIT             NOT NULL CONSTRAINT DF_ExecutionFiles_is_deleted DEFAULT 0,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_ExecutionFiles_created_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_ExecutionFiles PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_ExecutionFiles_Executions FOREIGN KEY (execution_id)
            REFERENCES dbo.ScriptExecutions (id) ON DELETE CASCADE,
        CONSTRAINT CK_ExecutionFiles_type CHECK (
            file_type IN ('xlsx', 'csv', 'pdf', 'zip', 'txt', 'json', 'log', 'png', 'other')
        )
    );

    CREATE NONCLUSTERED INDEX IX_ExecutionFiles_execution_id ON dbo.ExecutionFiles (execution_id);
    CREATE NONCLUSTERED INDEX IX_ExecutionFiles_file_type ON dbo.ExecutionFiles (file_type);
    CREATE NONCLUSTERED INDEX IX_ExecutionFiles_created_at ON dbo.ExecutionFiles (created_at DESC);
END
GO

-- ============================================================
--  13. SystemSettings
-- ============================================================

IF OBJECT_ID('dbo.SystemSettings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SystemSettings (
        id                  INT             NOT NULL IDENTITY(1,1),
        environment_id      INT             NOT NULL,

        setting_key         NVARCHAR(150)   NOT NULL,
        setting_value       NVARCHAR(1000)  NOT NULL,
        description         NVARCHAR(500)   NULL,

        updated_by_user_id  INT             NULL,
        updated_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_SystemSettings_updated_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_SystemSettings PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_SystemSettings_key_env UNIQUE (setting_key, environment_id),
        CONSTRAINT FK_SystemSettings_Environments FOREIGN KEY (environment_id) REFERENCES dbo.Environments (id),
        CONSTRAINT FK_SystemSettings_Users FOREIGN KEY (updated_by_user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL
    );

    INSERT INTO dbo.SystemSettings (environment_id, setting_key, setting_value, description)
    VALUES
        (1, 'scripts_base_path',  'C:\PyFlow\dev\scripts\',     'Carpeta base de scripts DEV'),
        (1, 'logs_base_path',     'C:\PyFlow\dev\logs\',        'Carpeta de logs DEV'),
        (1, 'exports_base_path',  'C:\PyFlow\dev\exports\',     'Carpeta de exportaciones DEV'),
        (1, 'python_interpreter', 'py',                          'Intérprete Python DEV'),

        (2, 'scripts_base_path',  'C:\PyFlow\qa\scripts\',      'Carpeta base de scripts QA'),
        (2, 'logs_base_path',     'C:\PyFlow\qa\logs\',         'Carpeta de logs QA'),
        (2, 'exports_base_path',  'C:\PyFlow\qa\exports\',      'Carpeta de exportaciones QA'),
        (2, 'python_interpreter', 'py',                          'Intérprete Python QA'),

        (3, 'scripts_base_path',  'C:\PyFlow\prod\scripts\',    'Carpeta base de scripts PROD'),
        (3, 'logs_base_path',     'C:\PyFlow\prod\logs\',       'Carpeta de logs PROD'),
        (3, 'exports_base_path',  'C:\PyFlow\prod\exports\',    'Carpeta de exportaciones PROD'),
        (3, 'python_interpreter', 'py',                          'Intérprete Python PROD');
END
GO

-- ============================================================
--  14. NotificationChannels
-- ============================================================

IF OBJECT_ID('dbo.NotificationChannels', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NotificationChannels (
        id                  INT             NOT NULL IDENTITY(1,1),
        environment_id      INT             NOT NULL,
        secret_id           INT             NULL,

        name                NVARCHAR(150)   NOT NULL,
        channel_type        NVARCHAR(30)    NOT NULL,
        destination_default NVARCHAR(1000)  NULL,
        config_json         NVARCHAR(MAX)   NULL,

        is_active           BIT             NOT NULL CONSTRAINT DF_NotificationChannels_is_active DEFAULT 1,
        updated_by_user_id  INT             NULL,
        updated_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_NotificationChannels_updated_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_NotificationChannels PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_NotificationChannels_name_env UNIQUE (environment_id, name),
        CONSTRAINT FK_NotificationChannels_Environments FOREIGN KEY (environment_id) REFERENCES dbo.Environments (id),
        CONSTRAINT FK_NotificationChannels_Secrets FOREIGN KEY (secret_id) REFERENCES dbo.Secrets (id) ON DELETE SET NULL,
        CONSTRAINT FK_NotificationChannels_Users FOREIGN KEY (updated_by_user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL,
        CONSTRAINT CK_NotificationChannels_type CHECK (
            channel_type IN ('graph_api', 'outlook_desktop', 'smtp', 'teams_webhook', 'slack_webhook')
        )
    );

    CREATE NONCLUSTERED INDEX IX_NotificationChannels_environment ON dbo.NotificationChannels (environment_id);
    CREATE NONCLUSTERED INDEX IX_NotificationChannels_type ON dbo.NotificationChannels (channel_type);
END
GO

-- ============================================================
--  15. Notifications
-- ============================================================

IF OBJECT_ID('dbo.Notifications', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Notifications (
        id                      BIGINT          NOT NULL IDENTITY(1,1),
        execution_id            INT             NULL,
        notification_channel_id INT             NULL,

        notification_type       NVARCHAR(30)    NOT NULL,
        recipient_to            NVARCHAR(MAX)   NULL,
        recipient_cc            NVARCHAR(MAX)   NULL,
        subject                 NVARCHAR(500)   NULL,
        body_preview            NVARCHAR(1000)  NULL,

        status                  NVARCHAR(20)    NOT NULL CONSTRAINT DF_Notifications_status DEFAULT 'Pendiente',
        provider_message_id     NVARCHAR(255)   NULL,
        error_message           NVARCHAR(MAX)   NULL,

        created_at              DATETIME2(0)    NOT NULL CONSTRAINT DF_Notifications_created_at DEFAULT SYSUTCDATETIME(),
        sent_at                 DATETIME2(0)    NULL,

        CONSTRAINT PK_Notifications PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_Notifications_Executions FOREIGN KEY (execution_id)
            REFERENCES dbo.ScriptExecutions (id) ON DELETE SET NULL,
        CONSTRAINT FK_Notifications_Channels FOREIGN KEY (notification_channel_id)
            REFERENCES dbo.NotificationChannels (id) ON DELETE SET NULL,
        CONSTRAINT CK_Notifications_type CHECK (
            notification_type IN ('success', 'error', 'warning', 'report', 'manual')
        ),
        CONSTRAINT CK_Notifications_status CHECK (
            status IN ('Pendiente', 'Enviado', 'Error', 'Cancelado')
        )
    );

    CREATE NONCLUSTERED INDEX IX_Notifications_execution_id ON dbo.Notifications (execution_id);
    CREATE NONCLUSTERED INDEX IX_Notifications_status ON dbo.Notifications (status);
    CREATE NONCLUSTERED INDEX IX_Notifications_created_at ON dbo.Notifications (created_at DESC);
END
GO

-- ============================================================
--  16. AlertConfigurations
-- ============================================================

IF OBJECT_ID('dbo.AlertConfigurations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AlertConfigurations (
        id                      INT             NOT NULL IDENTITY(1,1),
        script_id               INT             NULL,
        notification_channel_id INT             NOT NULL,

        alert_event             NVARCHAR(30)    NOT NULL,
        destination_override    NVARCHAR(MAX)   NULL,
        is_active               BIT             NOT NULL CONSTRAINT DF_AlertConfigurations_is_active DEFAULT 1,

        updated_by_user_id      INT             NULL,
        updated_at              DATETIME2(0)    NOT NULL CONSTRAINT DF_AlertConfigurations_updated_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_AlertConfigurations PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_AlertConfigurations_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts (id) ON DELETE CASCADE,
        CONSTRAINT FK_AlertConfigurations_Channels FOREIGN KEY (notification_channel_id) REFERENCES dbo.NotificationChannels (id),
        CONSTRAINT FK_AlertConfigurations_Users FOREIGN KEY (updated_by_user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL,
        CONSTRAINT CK_AlertConfigurations_event CHECK (
            alert_event IN ('on_success', 'on_error', 'on_warning', 'on_start', 'on_finish')
        )
    );

    CREATE NONCLUSTERED INDEX IX_AlertConfigurations_script_id ON dbo.AlertConfigurations (script_id);
    CREATE NONCLUSTERED INDEX IX_AlertConfigurations_channel_id ON dbo.AlertConfigurations (notification_channel_id);
END
GO

-- ============================================================
--  17. AuditLog
-- ============================================================

IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog (
        id              BIGINT          NOT NULL IDENTITY(1,1),
        user_id         INT             NULL,

        action          NVARCHAR(50)    NOT NULL,
        entity_type     NVARCHAR(100)   NOT NULL,
        entity_id       INT             NULL,

        old_value       NVARCHAR(MAX)   NULL,
        new_value       NVARCHAR(MAX)   NULL,

        performed_at    DATETIME2(3)    NOT NULL CONSTRAINT DF_AuditLog_performed_at DEFAULT SYSUTCDATETIME(),
        ip_address      NVARCHAR(45)    NULL,
        user_agent      NVARCHAR(1000)  NULL,

        CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_AuditLog_Users FOREIGN KEY (user_id) REFERENCES dbo.Users (id) ON DELETE SET NULL,
        CONSTRAINT CK_AuditLog_action CHECK (
            action IN ('CREATE', 'UPDATE', 'DELETE', 'EXECUTE', 'LOGIN', 'LOGOUT', 'CANCEL', 'VIEW_SECRET')
        )
    );

    CREATE NONCLUSTERED INDEX IX_AuditLog_user_id ON dbo.AuditLog (user_id);
    CREATE NONCLUSTERED INDEX IX_AuditLog_entity ON dbo.AuditLog (entity_type, entity_id);
    CREATE NONCLUSTERED INDEX IX_AuditLog_performed_at ON dbo.AuditLog (performed_at DESC);
END
GO

-- ============================================================
--  18. Views
-- ============================================================

CREATE OR ALTER VIEW dbo.vw_ScriptsSummary
AS
SELECT
    s.id,
    s.name,
    s.description,
    s.category,
    s.current_version,
    s.file_path,
    s.is_active,
    s.allow_manual_run,
    e.name AS environment_name,
    u.username AS created_by,

    last_ex.id AS last_execution_id,
    last_ex.status AS last_execution_status,
    last_ex.start_time AS last_execution_start_time,
    last_ex.end_time AS last_execution_end_time,
    last_ex.duration_seconds AS last_duration_seconds,
    last_ex.error_message AS last_error_message,

    sch.id AS schedule_id,
    sch.cron_expression,
    sch.frequency_label,
    sch.next_run_at,

    success_count.total_success,
    error_count.total_errors
FROM dbo.Scripts s
JOIN dbo.Environments e ON e.id = s.environment_id
JOIN dbo.Users u ON u.id = s.created_by_user_id
OUTER APPLY (
    SELECT TOP 1
        ex.id,
        ex.status,
        ex.start_time,
        ex.end_time,
        ex.duration_seconds,
        ex.error_message
    FROM dbo.ScriptExecutions ex
    WHERE ex.script_id = s.id
    ORDER BY ex.start_time DESC
) last_ex
OUTER APPLY (
    SELECT COUNT(*) AS total_success
    FROM dbo.ScriptExecutions ex
    WHERE ex.script_id = s.id AND ex.status = 'Exitoso'
) success_count
OUTER APPLY (
    SELECT COUNT(*) AS total_errors
    FROM dbo.ScriptExecutions ex
    WHERE ex.script_id = s.id AND ex.status = 'Error'
) error_count
LEFT JOIN dbo.Schedules sch
    ON sch.script_id = s.id AND sch.is_active = 1;
GO

CREATE OR ALTER VIEW dbo.vw_RunningExecutions
AS
SELECT
    ex.id AS execution_id,
    s.name AS script_name,
    s.category,
    env.name AS environment_name,
    u.username AS triggered_by,
    ex.trigger_type,
    ex.start_time,
    DATEDIFF(SECOND, ex.start_time, SYSUTCDATETIME()) AS elapsed_seconds,
    ex.process_id,
    ex.machine_name
FROM dbo.ScriptExecutions ex
JOIN dbo.Scripts s ON s.id = ex.script_id
JOIN dbo.Environments env ON env.id = s.environment_id
LEFT JOIN dbo.Users u ON u.id = ex.triggered_by_user_id
WHERE ex.status = 'Ejecutando';
GO

CREATE OR ALTER VIEW dbo.vw_ExecutionFiles
AS
SELECT
    f.id,
    f.execution_id,
    f.file_name,
    f.file_type,
    f.mime_type,
    f.file_path,
    CAST(f.file_size_bytes / 1048576.0 AS DECIMAL(18,2)) AS file_size_mb,
    f.created_at,
    s.name AS script_name,
    ex.status AS execution_status,
    ex.start_time AS execution_start_time
FROM dbo.ExecutionFiles f
JOIN dbo.ScriptExecutions ex ON ex.id = f.execution_id
JOIN dbo.Scripts s ON s.id = ex.script_id
WHERE f.is_deleted = 0;
GO

CREATE OR ALTER VIEW dbo.vw_RecentErrors
AS
SELECT TOP 200
    ex.id AS execution_id,
    s.name AS script_name,
    env.name AS environment_name,
    ex.start_time,
    ex.end_time,
    ex.duration_seconds,
    ex.error_message,
    last_log.message AS last_error_log
FROM dbo.ScriptExecutions ex
JOIN dbo.Scripts s ON s.id = ex.script_id
JOIN dbo.Environments env ON env.id = s.environment_id
OUTER APPLY (
    SELECT TOP 1 l.message
    FROM dbo.ExecutionLogs l
    WHERE l.execution_id = ex.id
      AND l.log_level IN ('ERROR', 'CRITICAL')
    ORDER BY l.logged_at DESC
) last_log
WHERE ex.status = 'Error'
ORDER BY ex.start_time DESC;
GO

-- ============================================================
--  19. Stored procedures operationales
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetExecutionOrder
    @root_script_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH DependencyChain AS (
        SELECT
            s.id,
            s.name,
            CAST(0 AS INT) AS depth,
            CAST(s.name AS NVARCHAR(MAX)) AS chain_path
        FROM dbo.Scripts s
        WHERE s.id = @root_script_id

        UNION ALL

        SELECT
            dep.depends_on_script_id,
            s2.name,
            dc.depth + 1,
            CAST(dc.chain_path + N' -> ' + s2.name AS NVARCHAR(MAX))
        FROM dbo.ScriptDependencies dep
        JOIN dbo.Scripts s2 ON s2.id = dep.depends_on_script_id
        JOIN DependencyChain dc ON dc.id = dep.script_id
        WHERE dep.is_active = 1
    )
    SELECT
        id AS script_id,
        name AS script_name,
        depth,
        chain_path
    FROM DependencyChain
    ORDER BY depth DESC, script_name;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_StartScriptExecution
    @script_id               INT,
    @script_version_id       INT = NULL,
    @schedule_id             INT = NULL,
    @triggered_by_user_id    INT = NULL,
    @parent_execution_id     INT = NULL,
    @trigger_type            NVARCHAR(20) = 'manual',
    @command_line            NVARCHAR(MAX) = NULL,
    @working_directory       NVARCHAR(1000) = NULL,
    @machine_name            NVARCHAR(255) = NULL,
    @process_id              INT = NULL,
    @execution_id            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ScriptExecutions (
        script_id,
        script_version_id,
        schedule_id,
        triggered_by_user_id,
        parent_execution_id,
        trigger_type,
        command_line,
        working_directory,
        machine_name,
        process_id
    )
    VALUES (
        @script_id,
        @script_version_id,
        @schedule_id,
        @triggered_by_user_id,
        @parent_execution_id,
        @trigger_type,
        @command_line,
        @working_directory,
        @machine_name,
        @process_id
    );

    SET @execution_id = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_FinishScriptExecution
    @execution_id       INT,
    @status             NVARCHAR(20),
    @exit_code          INT = NULL,
    @error_message      NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.ScriptExecutions
    SET
        status = @status,
        end_time = SYSUTCDATETIME(),
        exit_code = @exit_code,
        error_message = @error_message
    WHERE id = @execution_id;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_AddExecutionLog
    @execution_id    INT,
    @log_level       NVARCHAR(10),
    @message         NVARCHAR(MAX),
    @line_number     INT = NULL,
    @source          NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ExecutionLogs (
        execution_id,
        log_level,
        message,
        line_number,
        source
    )
    VALUES (
        @execution_id,
        @log_level,
        @message,
        @line_number,
        @source
    );
END
GO

-- ============================================================
--  20. Verificación final
-- ============================================================

SELECT
    t.name AS table_name,
    SUM(p.rows) AS estimated_rows
FROM sys.tables t
JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE t.is_ms_shipped = 0
  AND p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;
GO

PRINT '============================================================';
PRINT ' PyFlow Manager - Schema creado exitosamente';
PRINT ' Version: 3.0';
PRINT ' Tablas principales: 17';
PRINT ' Views: 4';
PRINT ' Stored Procedures: 6';
PRINT ' Triggers: 1';
PRINT '============================================================';
GO
