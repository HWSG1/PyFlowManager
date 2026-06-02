/*
  PyFlow Manager - SQL Server local schema
  Uso: ejecutar en master. Crea la base PyFlowManager si no existe y luego crea objetos.
*/
IF DB_ID(N'PyFlowManager') IS NULL
BEGIN
  CREATE DATABASE PyFlowManager;
END;
GO
USE PyFlowManager;
GO
/*
  PyFlow Manager - Azure SQL Database schema
  Uso: conectarse directamente a la base PyFlowManager y ejecutar este script.
  No incluye CREATE DATABASE porque Azure SQL Database se crea desde el portal/CLI.
*/
SET NOCOUNT ON;
GO

/* Limpieza opcional: descomentar solo si desea recrear desde cero.
DROP VIEW IF EXISTS dbo.vw_ExecutionFiles;
DROP VIEW IF EXISTS dbo.vw_RecentErrors;
DROP VIEW IF EXISTS dbo.vw_RunningExecutions;
DROP VIEW IF EXISTS dbo.vw_ScriptsSummary;
DROP PROCEDURE IF EXISTS dbo.usp_AddExecutionLog;
DROP PROCEDURE IF EXISTS dbo.usp_FinishScriptExecution;
DROP PROCEDURE IF EXISTS dbo.usp_StartScriptExecution;
DROP PROCEDURE IF EXISTS dbo.usp_GetExecutionOrder;
DROP TABLE IF EXISTS dbo.ExecutionFiles;
DROP TABLE IF EXISTS dbo.ExecutionLogs;
DROP TABLE IF EXISTS dbo.ExecutionParameters;
DROP TABLE IF EXISTS dbo.ExecutionQueue;
DROP TABLE IF EXISTS dbo.ScheduleParameters;
DROP TABLE IF EXISTS dbo.Schedules;
DROP TABLE IF EXISTS dbo.ScriptDependencies;
DROP TABLE IF EXISTS dbo.ScriptParameters;
DROP TABLE IF EXISTS dbo.ScriptVersions;
DROP TABLE IF EXISTS dbo.Secrets;
DROP TABLE IF EXISTS dbo.GlobalVariables;
DROP TABLE IF EXISTS dbo.SystemSettings;
DROP TABLE IF EXISTS dbo.ScriptExecutions;
DROP TABLE IF EXISTS dbo.Scripts;
DROP TABLE IF EXISTS dbo.Users;
DROP TABLE IF EXISTS dbo.Environments;
GO
*/

IF OBJECT_ID('dbo.Environments','U') IS NULL
CREATE TABLE dbo.Environments (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Environments PRIMARY KEY,
  name NVARCHAR(50) NOT NULL,
  description NVARCHAR(255) NULL,
  is_active BIT NOT NULL CONSTRAINT DF_Environments_is_active DEFAULT (1),
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_Environments_created_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT UQ_Environments_name UNIQUE (name)
);
GO

IF OBJECT_ID('dbo.Users','U') IS NULL
CREATE TABLE dbo.Users (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
  username NVARCHAR(100) NOT NULL,
  email NVARCHAR(255) NOT NULL,
  display_name NVARCHAR(255) NULL,
  auth_provider NVARCHAR(30) NOT NULL CONSTRAINT DF_Users_auth_provider DEFAULT ('local'),
  azure_ad_object_id NVARCHAR(100) NULL,
  domain_user NVARCHAR(150) NULL,
  password_hash NVARCHAR(512) NULL,
  role NVARCHAR(50) NOT NULL CONSTRAINT DF_Users_role DEFAULT ('Admin'),
  is_active BIT NOT NULL CONSTRAINT DF_Users_is_active DEFAULT (1),
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_Users_created_at DEFAULT (SYSUTCDATETIME()),
  updated_at DATETIME2(0) NULL,
  last_login DATETIME2(0) NULL,
  CONSTRAINT UQ_Users_username UNIQUE (username),
  CONSTRAINT UQ_Users_email UNIQUE (email)
);
GO

IF OBJECT_ID('dbo.Scripts','U') IS NULL
CREATE TABLE dbo.Scripts (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Scripts PRIMARY KEY,
  created_by_user_id INT NOT NULL,
  environment_id INT NOT NULL,
  name NVARCHAR(255) NOT NULL,
  description NVARCHAR(1000) NULL,
  category NVARCHAR(100) NOT NULL,
  current_version NVARCHAR(30) NOT NULL CONSTRAINT DF_Scripts_current_version DEFAULT ('1.0.0'),
  file_path NVARCHAR(1000) NOT NULL,
  working_directory NVARCHAR(1000) NULL,
  python_interpreter NVARCHAR(1000) NULL,
  author NVARCHAR(255) NULL,
  is_active BIT NOT NULL CONSTRAINT DF_Scripts_is_active DEFAULT (1),
  allow_manual_run BIT NOT NULL CONSTRAINT DF_Scripts_allow_manual_run DEFAULT (1),
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_Scripts_created_at DEFAULT (SYSUTCDATETIME()),
  updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_Scripts_updated_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT UQ_Scripts_name_env UNIQUE (name, environment_id),
  CONSTRAINT FK_Scripts_Users FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users(id),
  CONSTRAINT FK_Scripts_Environments FOREIGN KEY (environment_id) REFERENCES dbo.Environments(id)
);
GO

IF OBJECT_ID('dbo.ScriptVersions','U') IS NULL
CREATE TABLE dbo.ScriptVersions (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScriptVersions PRIMARY KEY,
  script_id INT NOT NULL,
  version NVARCHAR(30) NOT NULL,
  file_path NVARCHAR(1000) NOT NULL,
  checksum_sha256 NVARCHAR(128) NULL,
  change_notes NVARCHAR(MAX) NULL,
  created_by_user_id INT NULL,
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_ScriptVersions_created_at DEFAULT (SYSUTCDATETIME()),
  is_current BIT NOT NULL CONSTRAINT DF_ScriptVersions_is_current DEFAULT (0),
  CONSTRAINT UQ_ScriptVersions UNIQUE (script_id, version),
  CONSTRAINT FK_ScriptVersions_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts(id),
  CONSTRAINT FK_ScriptVersions_Users FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users(id)
);
GO

IF OBJECT_ID('dbo.ScriptExecutions','U') IS NULL
CREATE TABLE dbo.ScriptExecutions (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScriptExecutions PRIMARY KEY,
  script_id INT NOT NULL,
  script_version_id INT NULL,
  schedule_id INT NULL,
  triggered_by_user_id INT NULL,
  parent_execution_id INT NULL,
  status NVARCHAR(20) NOT NULL CONSTRAINT DF_ScriptExecutions_status DEFAULT ('Pendiente'),
  trigger_type NVARCHAR(20) NOT NULL CONSTRAINT DF_ScriptExecutions_trigger DEFAULT ('manual'),
  start_time DATETIME2(3) NOT NULL CONSTRAINT DF_ScriptExecutions_start_time DEFAULT (SYSUTCDATETIME()),
  end_time DATETIME2(3) NULL,
  duration_seconds INT NULL,
  exit_code INT NULL,
  retry_attempt SMALLINT NOT NULL CONSTRAINT DF_ScriptExecutions_retry DEFAULT (0),
  process_id INT NULL,
  machine_name NVARCHAR(255) NULL,
  command_line NVARCHAR(MAX) NULL,
  working_directory NVARCHAR(1000) NULL,
  error_message NVARCHAR(MAX) NULL,
  CONSTRAINT FK_ScriptExecutions_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts(id),
  CONSTRAINT FK_ScriptExecutions_Versions FOREIGN KEY (script_version_id) REFERENCES dbo.ScriptVersions(id),
  CONSTRAINT FK_ScriptExecutions_Users FOREIGN KEY (triggered_by_user_id) REFERENCES dbo.Users(id),
  CONSTRAINT FK_ScriptExecutions_Parent FOREIGN KEY (parent_execution_id) REFERENCES dbo.ScriptExecutions(id)
);
GO

IF OBJECT_ID('dbo.Schedules','U') IS NULL
CREATE TABLE dbo.Schedules (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Schedules PRIMARY KEY,
  script_id INT NOT NULL,
  created_by_user_id INT NOT NULL,
  cron_expression NVARCHAR(100) NOT NULL,
  frequency_label NVARCHAR(150) NULL,
  timezone_name NVARCHAR(100) NOT NULL CONSTRAINT DF_Schedules_timezone DEFAULT ('America/Tegucigalpa'),
  next_run_at DATETIME2(0) NULL,
  last_run_at DATETIME2(0) NULL,
  last_status NVARCHAR(20) NULL,
  last_error NVARCHAR(MAX) NULL,
  run_on_startup BIT NOT NULL CONSTRAINT DF_Schedules_run_on_startup DEFAULT (0),
  is_active BIT NOT NULL CONSTRAINT DF_Schedules_is_active DEFAULT (1),
  max_retries SMALLINT NOT NULL CONSTRAINT DF_Schedules_max_retries DEFAULT (0),
  retry_delay_seconds INT NOT NULL CONSTRAINT DF_Schedules_retry_delay DEFAULT (60),
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_Schedules_created_at DEFAULT (SYSUTCDATETIME()),
  updated_at DATETIME2(0) NULL,
  CONSTRAINT FK_Schedules_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts(id),
  CONSTRAINT FK_Schedules_Users FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users(id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_ScriptExecutions_Schedules')
ALTER TABLE dbo.ScriptExecutions ADD CONSTRAINT FK_ScriptExecutions_Schedules FOREIGN KEY (schedule_id) REFERENCES dbo.Schedules(id);
GO

IF OBJECT_ID('dbo.ExecutionLogs','U') IS NULL
CREATE TABLE dbo.ExecutionLogs (
  id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExecutionLogs PRIMARY KEY,
  execution_id INT NOT NULL,
  log_level NVARCHAR(10) NOT NULL CONSTRAINT DF_ExecutionLogs_level DEFAULT ('INFO'),
  message NVARCHAR(MAX) NOT NULL,
  line_number INT NULL,
  source NVARCHAR(100) NULL,
  logged_at DATETIME2(3) NOT NULL CONSTRAINT DF_ExecutionLogs_logged_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT FK_ExecutionLogs_Executions FOREIGN KEY (execution_id) REFERENCES dbo.ScriptExecutions(id) ON DELETE CASCADE
);
GO

IF OBJECT_ID('dbo.ExecutionParameters','U') IS NULL
CREATE TABLE dbo.ExecutionParameters (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExecutionParameters PRIMARY KEY,
  execution_id INT NOT NULL,
  param_key NVARCHAR(150) NOT NULL,
  param_value NVARCHAR(MAX) NULL,
  CONSTRAINT FK_ExecutionParameters_Execution FOREIGN KEY (execution_id) REFERENCES dbo.ScriptExecutions(id) ON DELETE CASCADE
);
GO

IF OBJECT_ID('dbo.ExecutionFiles','U') IS NULL
CREATE TABLE dbo.ExecutionFiles (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExecutionFiles PRIMARY KEY,
  execution_id INT NOT NULL,
  file_path NVARCHAR(1000) NOT NULL,
  file_name NVARCHAR(255) NOT NULL,
  file_type NVARCHAR(50) NULL,
  file_size_bytes BIGINT NULL,
  is_deleted BIT NOT NULL CONSTRAINT DF_ExecutionFiles_is_deleted DEFAULT (0),
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_ExecutionFiles_created_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT FK_ExecutionFiles_Executions FOREIGN KEY (execution_id) REFERENCES dbo.ScriptExecutions(id) ON DELETE CASCADE
);
GO

IF OBJECT_ID('dbo.ExecutionQueue','U') IS NULL
CREATE TABLE dbo.ExecutionQueue (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExecutionQueue PRIMARY KEY,
  script_id INT NOT NULL,
  schedule_id INT NULL,
  parameters_json NVARCHAR(MAX) NULL,
  status NVARCHAR(20) NOT NULL CONSTRAINT DF_ExecutionQueue_status DEFAULT ('PENDING'),
  created_at DATETIME2(3) NOT NULL CONSTRAINT DF_ExecutionQueue_created_at DEFAULT (SYSUTCDATETIME()),
  started_at DATETIME2(3) NULL,
  completed_at DATETIME2(3) NULL,
  CONSTRAINT FK_ExecutionQueue_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts(id),
  CONSTRAINT FK_ExecutionQueue_Schedules FOREIGN KEY (schedule_id) REFERENCES dbo.Schedules(id)
);
GO

IF OBJECT_ID('dbo.GlobalVariables','U') IS NULL
CREATE TABLE dbo.GlobalVariables (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GlobalVariables PRIMARY KEY,
  var_key NVARCHAR(150) NOT NULL,
  var_value NVARCHAR(MAX) NULL,
  is_secret BIT NOT NULL CONSTRAINT DF_GlobalVariables_is_secret DEFAULT (0),
  description NVARCHAR(500) NULL,
  created_at DATETIME2(3) NOT NULL CONSTRAINT DF_GlobalVariables_created_at DEFAULT (SYSUTCDATETIME()),
  updated_at DATETIME2(3) NULL,
  CONSTRAINT UQ_GlobalVariables_var_key UNIQUE (var_key)
);
GO

IF OBJECT_ID('dbo.ScheduleParameters','U') IS NULL
CREATE TABLE dbo.ScheduleParameters (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScheduleParameters PRIMARY KEY,
  schedule_id INT NOT NULL,
  param_key NVARCHAR(150) NOT NULL,
  param_value NVARCHAR(MAX) NULL,
  created_at DATETIME2(3) NOT NULL CONSTRAINT DF_ScheduleParameters_created_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT FK_ScheduleParameters_Schedules FOREIGN KEY (schedule_id) REFERENCES dbo.Schedules(id) ON DELETE CASCADE,
  CONSTRAINT UQ_ScheduleParameters UNIQUE (schedule_id, param_key)
);
GO

IF OBJECT_ID('dbo.Secrets','U') IS NULL
CREATE TABLE dbo.Secrets (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Secrets PRIMARY KEY,
  secret_key NVARCHAR(150) NOT NULL,
  secret_value NVARCHAR(MAX) NULL,
  description NVARCHAR(500) NULL,
  updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_Secrets_updated_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT UQ_Secrets_secret_key UNIQUE (secret_key)
);
GO

IF OBJECT_ID('dbo.ScriptParameters','U') IS NULL
CREATE TABLE dbo.ScriptParameters (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScriptParameters PRIMARY KEY,
  script_id INT NOT NULL,
  secret_id INT NULL,
  param_key NVARCHAR(150) NOT NULL,
  param_value NVARCHAR(1000) NULL,
  param_type NVARCHAR(30) NOT NULL CONSTRAINT DF_ScriptParameters_type DEFAULT ('string'),
  is_secret BIT NOT NULL CONSTRAINT DF_ScriptParameters_is_secret DEFAULT (0),
  description NVARCHAR(500) NULL,
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_ScriptParameters_created_at DEFAULT (SYSUTCDATETIME()),
  updated_at DATETIME2(0) NULL,
  options_json NVARCHAR(MAX) NULL,
  label NVARCHAR(255) NULL,
  is_required BIT NOT NULL CONSTRAINT DF_ScriptParameters_is_required DEFAULT (0),
  control_type NVARCHAR(30) NULL,
  global_key NVARCHAR(150) NULL,
  CONSTRAINT UQ_ScriptParameters_key UNIQUE (script_id, param_key),
  CONSTRAINT FK_ScriptParameters_Scripts FOREIGN KEY (script_id) REFERENCES dbo.Scripts(id) ON DELETE CASCADE,
  CONSTRAINT FK_ScriptParameters_Secrets FOREIGN KEY (secret_id) REFERENCES dbo.Secrets(id)
);
GO

IF OBJECT_ID('dbo.ScriptDependencies','U') IS NULL
CREATE TABLE dbo.ScriptDependencies (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScriptDependencies PRIMARY KEY,
  script_id INT NOT NULL,
  depends_on_script_id INT NOT NULL,
  execution_order SMALLINT NOT NULL CONSTRAINT DF_ScriptDependencies_order DEFAULT (1),
  dependency_type NVARCHAR(20) NOT NULL CONSTRAINT DF_ScriptDependencies_type DEFAULT ('before'),
  is_active BIT NOT NULL CONSTRAINT DF_ScriptDependencies_is_active DEFAULT (1),
  created_at DATETIME2(0) NOT NULL CONSTRAINT DF_ScriptDependencies_created_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT FK_ScriptDep_Script FOREIGN KEY (script_id) REFERENCES dbo.Scripts(id),
  CONSTRAINT FK_ScriptDep_DependsOn FOREIGN KEY (depends_on_script_id) REFERENCES dbo.Scripts(id)
);
GO

IF OBJECT_ID('dbo.SystemSettings','U') IS NULL
CREATE TABLE dbo.SystemSettings (
  id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SystemSettings PRIMARY KEY,
  environment_id INT NOT NULL,
  setting_key NVARCHAR(150) NOT NULL,
  setting_value NVARCHAR(1000) NOT NULL,
  description NVARCHAR(500) NULL,
  updated_by_user_id INT NULL,
  updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_SystemSettings_updated_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT UQ_SystemSettings_key_env UNIQUE (setting_key, environment_id),
  CONSTRAINT FK_SystemSettings_Environments FOREIGN KEY (environment_id) REFERENCES dbo.Environments(id),
  CONSTRAINT FK_SystemSettings_Users FOREIGN KEY (updated_by_user_id) REFERENCES dbo.Users(id)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_StartScriptExecution
  @script_id INT,
  @script_version_id INT = NULL,
  @schedule_id INT = NULL,
  @triggered_by_user_id INT = NULL,
  @parent_execution_id INT = NULL,
  @trigger_type NVARCHAR(20),
  @command_line NVARCHAR(MAX),
  @working_directory NVARCHAR(1000),
  @machine_name NVARCHAR(255),
  @process_id INT = NULL,
  @execution_id INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;
  INSERT INTO dbo.ScriptExecutions (
    script_id, script_version_id, schedule_id, triggered_by_user_id,
    parent_execution_id, trigger_type, status, command_line,
    working_directory, machine_name, process_id, start_time
  )
  VALUES (
    @script_id, @script_version_id, @schedule_id, @triggered_by_user_id,
    @parent_execution_id, @trigger_type, N'Ejecutando', @command_line,
    @working_directory, @machine_name, @process_id, SYSUTCDATETIME()
  );
  SET @execution_id = CONVERT(INT, SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_FinishScriptExecution
  @execution_id INT,
  @status NVARCHAR(20),
  @exit_code INT = NULL,
  @error_message NVARCHAR(MAX) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE dbo.ScriptExecutions
  SET status = @status,
      end_time = SYSUTCDATETIME(),
      exit_code = @exit_code,
      error_message = @error_message,
      duration_seconds = DATEDIFF(SECOND, start_time, SYSUTCDATETIME())
  WHERE id = @execution_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AddExecutionLog
  @execution_id INT,
  @log_level NVARCHAR(10),
  @message NVARCHAR(MAX),
  @line_number INT = NULL,
  @source NVARCHAR(100) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  INSERT INTO dbo.ExecutionLogs (execution_id, log_level, message, line_number, source, logged_at)
  VALUES (@execution_id, @log_level, @message, @line_number, @source, SYSUTCDATETIME());
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetExecutionOrder
  @root_script_id INT
AS
BEGIN
  SET NOCOUNT ON;
  WITH DependencyChain AS (
    SELECT s.id, s.name, CAST(0 AS INT) AS depth, CAST(s.name AS NVARCHAR(MAX)) AS chain_path
    FROM dbo.Scripts s
    WHERE s.id = @root_script_id
    UNION ALL
    SELECT dep.depends_on_script_id, s2.name, dc.depth + 1,
           CAST(dc.chain_path + N' -> ' + s2.name AS NVARCHAR(MAX))
    FROM dbo.ScriptDependencies dep
    JOIN dbo.Scripts s2 ON s2.id = dep.depends_on_script_id
    JOIN DependencyChain dc ON dc.id = dep.script_id
    WHERE dep.is_active = 1
  )
  SELECT id AS script_id, name AS script_name, depth, chain_path
  FROM DependencyChain
  ORDER BY depth DESC, script_name;
END;
GO

CREATE OR ALTER VIEW dbo.vw_ScriptsSummary
AS
SELECT
  s.id, s.name, s.description, s.category, s.current_version, s.file_path,
  s.working_directory, s.python_interpreter, s.author, s.is_active, s.allow_manual_run,
  s.created_at, s.updated_at,
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
  SELECT TOP 1 ex.id, ex.status, ex.start_time, ex.end_time, ex.duration_seconds, ex.error_message
  FROM dbo.ScriptExecutions ex
  WHERE ex.script_id = s.id
  ORDER BY ex.start_time DESC
) last_ex
OUTER APPLY (
  SELECT TOP 1 sc.id, sc.cron_expression, sc.frequency_label, sc.next_run_at
  FROM dbo.Schedules sc
  WHERE sc.script_id = s.id AND sc.is_active = 1
  ORDER BY sc.next_run_at ASC
) sch
OUTER APPLY (
  SELECT COUNT(*) AS total_success FROM dbo.ScriptExecutions ex WHERE ex.script_id = s.id AND ex.status = N'Exitoso'
) success_count
OUTER APPLY (
  SELECT COUNT(*) AS total_errors FROM dbo.ScriptExecutions ex WHERE ex.script_id = s.id AND ex.status = N'Error'
) error_count;
GO

CREATE OR ALTER VIEW dbo.vw_RunningExecutions
AS
SELECT ex.id, ex.script_id, s.name AS script_name, ex.status, ex.trigger_type,
       ex.start_time, ex.process_id, ex.machine_name, ex.command_line, ex.working_directory,
       DATEDIFF(SECOND, ex.start_time, SYSUTCDATETIME()) AS elapsed_seconds
FROM dbo.ScriptExecutions ex
JOIN dbo.Scripts s ON s.id = ex.script_id
WHERE ex.status = N'Ejecutando';
GO

CREATE OR ALTER VIEW dbo.vw_RecentErrors
AS
SELECT TOP 100 ex.id, ex.script_id, s.name AS script_name, ex.status, ex.start_time,
       ex.end_time, ex.error_message, ex.exit_code
FROM dbo.ScriptExecutions ex
JOIN dbo.Scripts s ON s.id = ex.script_id
WHERE ex.status = N'Error'
ORDER BY ex.start_time DESC;
GO

CREATE OR ALTER VIEW dbo.vw_ExecutionFiles
AS
SELECT f.id, f.execution_id, f.file_path, f.file_name, f.file_type, f.file_size_bytes,
       f.is_deleted, f.created_at, ex.script_id, s.name AS script_name
FROM dbo.ExecutionFiles f
JOIN dbo.ScriptExecutions ex ON ex.id = f.execution_id
JOIN dbo.Scripts s ON s.id = ex.script_id;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Environments WHERE name = 'Production')
INSERT INTO dbo.Environments (name, description) VALUES ('Production', 'Ambiente productivo');
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Environments WHERE name = 'Development')
INSERT INTO dbo.Environments (name, description) VALUES ('Development', 'Ambiente de desarrollo');
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Environments WHERE id = 3)
SET IDENTITY_INSERT dbo.Environments ON;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Environments WHERE id = 3)
INSERT INTO dbo.Environments (id, name, description) VALUES (3, 'Default', 'Ambiente por defecto para configuración del backend');
GO
IF EXISTS (SELECT 1 FROM dbo.Environments WHERE id = 3)
SET IDENTITY_INSERT dbo.Environments OFF;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE id = 1)
BEGIN
  SET IDENTITY_INSERT dbo.Users ON;
  INSERT INTO dbo.Users (id, username, email, display_name, role)
  VALUES (1, 'admin', 'admin@local', 'Administrador', 'Admin');
  SET IDENTITY_INSERT dbo.Users OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE environment_id = 3 AND setting_key = 'MAX_CONCURRENT_EXECUTIONS')
INSERT INTO dbo.SystemSettings (environment_id, setting_key, setting_value, description, updated_by_user_id)
VALUES (3, 'MAX_CONCURRENT_EXECUTIONS', '3', 'Máximo de ejecuciones simultáneas', 1);
GO
