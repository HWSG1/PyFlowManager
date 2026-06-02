-- ============================================================
--  PyFlowManager - Script SQL Server (LOCAL)
--  Versión corregida — Junio 2026
--
--  FIXES aplicados:
--    1. CREATE LOGIN pyflow_user agregado en master
--    2. CREATE CERTIFICATE + SYMMETRIC KEY para cifrado de Secrets
--    3. GETDATE() → SYSUTCDATETIME() en SPs y DEFAULT constraints
--    4. DEFAULT constraints de EP/EQ/SP unificados a SYSUTCDATETIME()
--
--  INSTRUCCIONES:
--    - Ejecutar con un login SA o sysadmin en SQL Server local
--    - Ajustar el PASSWORD del login pyflow_user antes de ejecutar
--    - NO ejecutar con usuario pyflowadmin (no tiene permisos en master)
-- ============================================================

USE [master];
GO

-- ============================================================
--  1. Login de aplicación (autenticación SQL)
--     ► Cambia la contraseña antes de ejecutar en producción
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'pyflow_user')
BEGIN
    CREATE LOGIN [pyflow_user]
        WITH PASSWORD   = N'PyFlow@App2026!',   -- ◄ CAMBIAR
             CHECK_POLICY = OFF,
             DEFAULT_DATABASE = [PyFlowManager];
END
GO

CREATE DATABASE [PyFlowManager]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'PyFlowManager', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\PyFlowManager.mdf' , SIZE = 73728KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'PyFlowManager_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\PyFlowManager_log.ldf' , SIZE = 73728KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO
ALTER DATABASE [PyFlowManager] SET COMPATIBILITY_LEVEL = 170
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [PyFlowManager].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [PyFlowManager] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [PyFlowManager] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [PyFlowManager] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [PyFlowManager] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [PyFlowManager] SET ARITHABORT OFF 
GO
ALTER DATABASE [PyFlowManager] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [PyFlowManager] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [PyFlowManager] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [PyFlowManager] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [PyFlowManager] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [PyFlowManager] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [PyFlowManager] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [PyFlowManager] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [PyFlowManager] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [PyFlowManager] SET  ENABLE_BROKER 
GO
ALTER DATABASE [PyFlowManager] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [PyFlowManager] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [PyFlowManager] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [PyFlowManager] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [PyFlowManager] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [PyFlowManager] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [PyFlowManager] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [PyFlowManager] SET RECOVERY FULL 
GO
ALTER DATABASE [PyFlowManager] SET  MULTI_USER 
GO
ALTER DATABASE [PyFlowManager] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [PyFlowManager] SET DB_CHAINING OFF 
GO
ALTER DATABASE [PyFlowManager] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [PyFlowManager] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [PyFlowManager] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [PyFlowManager] SET OPTIMIZED_LOCKING = OFF 
GO
ALTER DATABASE [PyFlowManager] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [PyFlowManager] SET QUERY_STORE = ON
GO
ALTER DATABASE [PyFlowManager] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
USE [PyFlowManager]
GO
/****** Objeto: User [pyflow_user] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE USER [pyflow_user] FOR LOGIN [pyflow_user] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [pyflow_user]
GO
ALTER ROLE [db_ddladmin] ADD MEMBER [pyflow_user]
GO
ALTER ROLE [db_datareader] ADD MEMBER [pyflow_user]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [pyflow_user]
GO
/****** Objeto: Table [dbo].[Schedules] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
--  2. Certificado y Symmetric Key para cifrado de Secrets
--     Requeridos por usp_GetSecret y usp_InsertSecret
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'PyFlowSecretsCert')
BEGIN
    CREATE CERTIFICATE PyFlowSecretsCert
        WITH SUBJECT = 'PyFlow Secrets Encryption';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'PyFlowSecretsKey')
BEGIN
    CREATE SYMMETRIC KEY PyFlowSecretsKey
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE PyFlowSecretsCert;
END
GO

CREATE TABLE [dbo].[Schedules](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[script_id] [int] NOT NULL,
	[created_by_user_id] [int] NOT NULL,
	[cron_expression] [nvarchar](100) NOT NULL,
	[frequency_label] [nvarchar](150) NULL,
	[timezone_name] [nvarchar](100) NOT NULL,
	[next_run_at] [datetime2](0) NULL,
	[last_run_at] [datetime2](0) NULL,
	[last_status] [nvarchar](20) NULL,
	[last_error] [nvarchar](max) NULL,
	[run_on_startup] [bit] NOT NULL,
	[is_active] [bit] NOT NULL,
	[max_retries] [smallint] NOT NULL,
	[retry_delay_seconds] [int] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
	[updated_at] [datetime2](0) NULL,
 CONSTRAINT [PK_Schedules] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[ScriptExecutions] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ScriptExecutions](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[script_id] [int] NOT NULL,
	[script_version_id] [int] NULL,
	[schedule_id] [int] NULL,
	[triggered_by_user_id] [int] NULL,
	[parent_execution_id] [int] NULL,
	[status] [nvarchar](20) NOT NULL,
	[trigger_type] [nvarchar](20) NOT NULL,
	[start_time] [datetime2](3) NOT NULL,
	[end_time] [datetime2](3) NULL,
	[duration_seconds] [int] NULL,
	[exit_code] [int] NULL,
	[retry_attempt] [smallint] NOT NULL,
	[process_id] [int] NULL,
	[machine_name] [nvarchar](255) NULL,
	[command_line] [nvarchar](max) NULL,
	[working_directory] [nvarchar](1000) NULL,
	[error_message] [nvarchar](max) NULL,
 CONSTRAINT [PK_ScriptExecutions] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Environments] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Environments](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](255) NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_Environments] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Environments_name] UNIQUE NONCLUSTERED 
(
	[name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Users] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[username] [nvarchar](100) NOT NULL,
	[email] [nvarchar](255) NOT NULL,
	[display_name] [nvarchar](255) NULL,
	[auth_provider] [nvarchar](30) NOT NULL,
	[azure_ad_object_id] [nvarchar](100) NULL,
	[domain_user] [nvarchar](150) NULL,
	[password_hash] [nvarchar](512) NULL,
	[role] [nvarchar](50) NOT NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
	[updated_at] [datetime2](0) NULL,
	[last_login] [datetime2](0) NULL,
 CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Users_email] UNIQUE NONCLUSTERED 
(
	[email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Users_username] UNIQUE NONCLUSTERED 
(
	[username] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Scripts] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Scripts](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[created_by_user_id] [int] NOT NULL,
	[environment_id] [int] NOT NULL,
	[name] [nvarchar](255) NOT NULL,
	[description] [nvarchar](1000) NULL,
	[category] [nvarchar](100) NOT NULL,
	[current_version] [nvarchar](30) NOT NULL,
	[file_path] [nvarchar](1000) NOT NULL,
	[working_directory] [nvarchar](1000) NULL,
	[python_interpreter] [nvarchar](1000) NULL,
	[author] [nvarchar](255) NULL,
	[is_active] [bit] NOT NULL,
	[allow_manual_run] [bit] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
	[updated_at] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_Scripts] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Scripts_name_env] UNIQUE NONCLUSTERED 
(
	[name] ASC,
	[environment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: View [dbo].[vw_ScriptsSummary] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[vw_ScriptsSummary]
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
    s.created_at,
    s.updated_at,
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
JOIN dbo.Environments e
    ON e.id = s.environment_id
JOIN dbo.Users u
    ON u.id = s.created_by_user_id
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
    WHERE ex.script_id = s.id
      AND ex.status = 'Exitoso'
) success_count
OUTER APPLY (
    SELECT COUNT(*) AS total_errors
    FROM dbo.ScriptExecutions ex
    WHERE ex.script_id = s.id
      AND ex.status = 'Error'
) error_count
LEFT JOIN dbo.Schedules sch
    ON sch.script_id = s.id
   AND sch.is_active = 1;
GO
/****** Objeto: View [dbo].[vw_RunningExecutions] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[vw_RunningExecutions]
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
/****** Objeto: Table [dbo].[ExecutionFiles] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExecutionFiles](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[execution_id] [int] NOT NULL,
	[file_name] [nvarchar](255) NOT NULL,
	[file_path] [nvarchar](1000) NOT NULL,
	[file_type] [nvarchar](30) NOT NULL,
	[mime_type] [nvarchar](150) NULL,
	[file_size_bytes] [bigint] NULL,
	[checksum_sha256] [nvarchar](128) NULL,
	[is_deleted] [bit] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ExecutionFiles] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: View [dbo].[vw_ExecutionFiles] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[vw_ExecutionFiles]
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
/****** Objeto: Table [dbo].[ExecutionLogs] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExecutionLogs](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[execution_id] [int] NOT NULL,
	[log_level] [nvarchar](10) NOT NULL,
	[message] [nvarchar](max) NOT NULL,
	[logged_at] [datetime2](3) NOT NULL,
	[line_number] [int] NULL,
	[source] [nvarchar](100) NULL,
 CONSTRAINT [PK_ExecutionLogs] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: View [dbo].[vw_RecentErrors] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[vw_RecentErrors]
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
/****** Objeto: Table [dbo].[ExecutionParameters] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExecutionParameters](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[execution_id] [int] NOT NULL,
	[param_key] [nvarchar](150) NOT NULL,
	[param_value] [nvarchar](max) NULL,
	[created_at] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[ExecutionQueue] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExecutionQueue](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[script_id] [int] NOT NULL,
	[schedule_id] [int] NULL,
	[parameters_json] [nvarchar](max) NULL,
	[status] [nvarchar](20) NULL,
	[created_at] [datetime2](7) NULL,
	[started_at] [datetime2](7) NULL,
	[completed_at] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[GlobalVariables] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GlobalVariables](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[var_key] [nvarchar](150) NOT NULL,
	[var_value] [nvarchar](max) NULL,
	[is_secret] [bit] NOT NULL,
	[description] [nvarchar](500) NULL,
	[created_at] [datetime2](7) NOT NULL,
	[updated_at] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[var_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[ScheduleParameters] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ScheduleParameters](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[schedule_id] [int] NOT NULL,
	[param_key] [nvarchar](150) NOT NULL,
	[param_value] [nvarchar](max) NULL,
	[created_at] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[ScriptDependencies] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ScriptDependencies](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[script_id] [int] NOT NULL,
	[depends_on_script_id] [int] NOT NULL,
	[execution_order] [smallint] NOT NULL,
	[dependency_type] [nvarchar](20) NOT NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ScriptDependencies] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ScriptDependencies] UNIQUE NONCLUSTERED 
(
	[script_id] ASC,
	[depends_on_script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[ScriptParameters] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ScriptParameters](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[script_id] [int] NOT NULL,
	[secret_id] [int] NULL,
	[param_key] [nvarchar](150) NOT NULL,
	[param_value] [nvarchar](1000) NULL,
	[param_type] [nvarchar](30) NOT NULL,
	[is_secret] [bit] NOT NULL,
	[description] [nvarchar](500) NULL,
	[created_at] [datetime2](0) NOT NULL,
	[updated_at] [datetime2](0) NULL,
	[options_json] [nvarchar](max) NULL,
	[label] [nvarchar](255) NULL,
	[is_required] [bit] NOT NULL,
	[control_type] [nvarchar](30) NULL,
	[global_key] [nvarchar](150) NULL,
 CONSTRAINT [PK_ScriptParameters] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ScriptParameters_key] UNIQUE NONCLUSTERED 
(
	[script_id] ASC,
	[param_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[ScriptVersions] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ScriptVersions](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[script_id] [int] NOT NULL,
	[version] [nvarchar](30) NOT NULL,
	[file_path] [nvarchar](1000) NOT NULL,
	[checksum_sha256] [nvarchar](128) NULL,
	[change_notes] [nvarchar](max) NULL,
	[created_by_user_id] [int] NULL,
	[created_at] [datetime2](0) NOT NULL,
	[is_current] [bit] NOT NULL,
 CONSTRAINT [PK_ScriptVersions] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ScriptVersions_script_version] UNIQUE NONCLUSTERED 
(
	[script_id] ASC,
	[version] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Secrets] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Secrets](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[secret_key] [nvarchar](150) NOT NULL,
	[encrypted_value] [varbinary](max) NOT NULL,
	[description] [nvarchar](500) NULL,
	[updated_by_user_id] [int] NULL,
	[updated_at] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_Secrets] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Secrets_secret_key] UNIQUE NONCLUSTERED 
(
	[secret_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[SystemSettings] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SystemSettings](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[environment_id] [int] NOT NULL,
	[setting_key] [nvarchar](150) NOT NULL,
	[setting_value] [nvarchar](1000) NOT NULL,
	[description] [nvarchar](500) NULL,
	[updated_by_user_id] [int] NULL,
	[updated_at] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SystemSettings] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SystemSettings_key_env] UNIQUE NONCLUSTERED 
(
	[setting_key] ASC,
	[environment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ExecutionFiles_created_at] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ExecutionFiles_created_at] ON [dbo].[ExecutionFiles]
(
	[created_at] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ExecutionFiles_execution_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ExecutionFiles_execution_id] ON [dbo].[ExecutionFiles]
(
	[execution_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_ExecutionFiles_file_type] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ExecutionFiles_file_type] ON [dbo].[ExecutionFiles]
(
	[file_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ExecutionLogs_execution_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ExecutionLogs_execution_id] ON [dbo].[ExecutionLogs]
(
	[execution_id] ASC,
	[logged_at] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_ExecutionLogs_level] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ExecutionLogs_level] ON [dbo].[ExecutionLogs]
(
	[log_level] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Schedules_is_active] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Schedules_is_active] ON [dbo].[Schedules]
(
	[is_active] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Schedules_next_run] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Schedules_next_run] ON [dbo].[Schedules]
(
	[next_run_at] ASC
)
WHERE ([is_active]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Schedules_script_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Schedules_script_id] ON [dbo].[Schedules]
(
	[script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ScriptDep_depends_on] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ScriptDep_depends_on] ON [dbo].[ScriptDependencies]
(
	[depends_on_script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ScriptDep_script_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ScriptDep_script_id] ON [dbo].[ScriptDependencies]
(
	[script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Executions_schedule_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Executions_schedule_id] ON [dbo].[ScriptExecutions]
(
	[schedule_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Executions_script_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Executions_script_id] ON [dbo].[ScriptExecutions]
(
	[script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Executions_start_time] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Executions_start_time] ON [dbo].[ScriptExecutions]
(
	[start_time] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_Executions_status] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Executions_status] ON [dbo].[ScriptExecutions]
(
	[status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ScriptParameters_script_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ScriptParameters_script_id] ON [dbo].[ScriptParameters]
(
	[script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_Scripts_category] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Scripts_category] ON [dbo].[Scripts]
(
	[category] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Scripts_environment] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Scripts_environment] ON [dbo].[Scripts]
(
	[environment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Scripts_is_active] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Scripts_is_active] ON [dbo].[Scripts]
(
	[is_active] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ScriptVersions_is_current] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ScriptVersions_is_current] ON [dbo].[ScriptVersions]
(
	[script_id] ASC,
	[is_current] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_ScriptVersions_script_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_ScriptVersions_script_id] ON [dbo].[ScriptVersions]
(
	[script_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_Secrets_secret_key] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Secrets_secret_key] ON [dbo].[Secrets]
(
	[secret_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_Users_azure_ad_object_id] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Users_azure_ad_object_id] ON [dbo].[Users]
(
	[azure_ad_object_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [IX_Users_email] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Users_email] ON [dbo].[Users]
(
	[email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Objeto: Index [IX_Users_is_active] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
CREATE NONCLUSTERED INDEX [IX_Users_is_active] ON [dbo].[Users]
(
	[is_active] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Environments] ADD  CONSTRAINT [DF_Environments_is_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[Environments] ADD  CONSTRAINT [DF_Environments_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ExecutionFiles] ADD  CONSTRAINT [DF_ExecutionFiles_is_deleted]  DEFAULT ((0)) FOR [is_deleted]
GO
ALTER TABLE [dbo].[ExecutionFiles] ADD  CONSTRAINT [DF_ExecutionFiles_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ExecutionLogs] ADD  CONSTRAINT [DF_ExecutionLogs_level]  DEFAULT ('INFO') FOR [log_level]
GO
ALTER TABLE [dbo].[ExecutionLogs] ADD  CONSTRAINT [DF_ExecutionLogs_logged_at]  DEFAULT (sysutcdatetime()) FOR [logged_at]
GO
ALTER TABLE [dbo].[ExecutionParameters] ADD  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ExecutionQueue] ADD  DEFAULT ('pending') FOR [status]
GO
ALTER TABLE [dbo].[ExecutionQueue] ADD  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[GlobalVariables] ADD  DEFAULT ((0)) FOR [is_secret]
GO
ALTER TABLE [dbo].[GlobalVariables] ADD  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ScheduleParameters] ADD  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[Schedules] ADD  CONSTRAINT [DF_Schedules_timezone]  DEFAULT ('America/Tegucigalpa') FOR [timezone_name]
GO
ALTER TABLE [dbo].[Schedules] ADD  CONSTRAINT [DF_Schedules_run_on_startup]  DEFAULT ((0)) FOR [run_on_startup]
GO
ALTER TABLE [dbo].[Schedules] ADD  CONSTRAINT [DF_Schedules_is_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[Schedules] ADD  CONSTRAINT [DF_Schedules_max_retries]  DEFAULT ((3)) FOR [max_retries]
GO
ALTER TABLE [dbo].[Schedules] ADD  CONSTRAINT [DF_Schedules_retry_delay]  DEFAULT ((60)) FOR [retry_delay_seconds]
GO
ALTER TABLE [dbo].[Schedules] ADD  CONSTRAINT [DF_Schedules_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ScriptDependencies] ADD  CONSTRAINT [DF_ScriptDependencies_order]  DEFAULT ((1)) FOR [execution_order]
GO
ALTER TABLE [dbo].[ScriptDependencies] ADD  CONSTRAINT [DF_ScriptDependencies_type]  DEFAULT ('hard') FOR [dependency_type]
GO
ALTER TABLE [dbo].[ScriptDependencies] ADD  CONSTRAINT [DF_ScriptDependencies_is_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[ScriptDependencies] ADD  CONSTRAINT [DF_ScriptDependencies_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ScriptExecutions] ADD  CONSTRAINT [DF_ScriptExecutions_status]  DEFAULT ('Ejecutando') FOR [status]
GO
ALTER TABLE [dbo].[ScriptExecutions] ADD  CONSTRAINT [DF_ScriptExecutions_trigger]  DEFAULT ('manual') FOR [trigger_type]
GO
ALTER TABLE [dbo].[ScriptExecutions] ADD  CONSTRAINT [DF_ScriptExecutions_start_time]  DEFAULT (sysutcdatetime()) FOR [start_time]
GO
ALTER TABLE [dbo].[ScriptExecutions] ADD  CONSTRAINT [DF_ScriptExecutions_retry]  DEFAULT ((0)) FOR [retry_attempt]
GO
ALTER TABLE [dbo].[ScriptParameters] ADD  CONSTRAINT [DF_ScriptParameters_type]  DEFAULT ('env') FOR [param_type]
GO
ALTER TABLE [dbo].[ScriptParameters] ADD  CONSTRAINT [DF_ScriptParameters_is_secret]  DEFAULT ((0)) FOR [is_secret]
GO
ALTER TABLE [dbo].[ScriptParameters] ADD  CONSTRAINT [DF_ScriptParameters_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ScriptParameters] ADD  DEFAULT ((0)) FOR [is_required]
GO
ALTER TABLE [dbo].[Scripts] ADD  CONSTRAINT [DF_Scripts_current_version]  DEFAULT ('1.0.0') FOR [current_version]
GO
ALTER TABLE [dbo].[Scripts] ADD  CONSTRAINT [DF_Scripts_is_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[Scripts] ADD  CONSTRAINT [DF_Scripts_allow_manual_run]  DEFAULT ((1)) FOR [allow_manual_run]
GO
ALTER TABLE [dbo].[Scripts] ADD  CONSTRAINT [DF_Scripts_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[Scripts] ADD  CONSTRAINT [DF_Scripts_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
GO
ALTER TABLE [dbo].[ScriptVersions] ADD  CONSTRAINT [DF_ScriptVersions_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ScriptVersions] ADD  CONSTRAINT [DF_ScriptVersions_is_current]  DEFAULT ((0)) FOR [is_current]
GO
ALTER TABLE [dbo].[Secrets] ADD  CONSTRAINT [DF_Secrets_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
GO
ALTER TABLE [dbo].[SystemSettings] ADD  CONSTRAINT [DF_SystemSettings_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_auth_provider]  DEFAULT ('local') FOR [auth_provider]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_role]  DEFAULT ('Viewer') FOR [role]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_is_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
GO
ALTER TABLE [dbo].[ExecutionFiles]  WITH CHECK ADD  CONSTRAINT [FK_ExecutionFiles_Executions] FOREIGN KEY([execution_id])
REFERENCES [dbo].[ScriptExecutions] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ExecutionFiles] CHECK CONSTRAINT [FK_ExecutionFiles_Executions]
GO
ALTER TABLE [dbo].[ExecutionLogs]  WITH CHECK ADD  CONSTRAINT [FK_ExecutionLogs_Executions] FOREIGN KEY([execution_id])
REFERENCES [dbo].[ScriptExecutions] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ExecutionLogs] CHECK CONSTRAINT [FK_ExecutionLogs_Executions]
GO
ALTER TABLE [dbo].[ExecutionParameters]  WITH CHECK ADD  CONSTRAINT [FK_ExecutionParameters_Execution] FOREIGN KEY([execution_id])
REFERENCES [dbo].[ScriptExecutions] ([id])
GO
ALTER TABLE [dbo].[ExecutionParameters] CHECK CONSTRAINT [FK_ExecutionParameters_Execution]
GO
ALTER TABLE [dbo].[ScheduleParameters]  WITH CHECK ADD  CONSTRAINT [FK_ScheduleParameters_Schedules] FOREIGN KEY([schedule_id])
REFERENCES [dbo].[Schedules] ([id])
GO
ALTER TABLE [dbo].[ScheduleParameters] CHECK CONSTRAINT [FK_ScheduleParameters_Schedules]
GO
ALTER TABLE [dbo].[Schedules]  WITH CHECK ADD  CONSTRAINT [FK_Schedules_Scripts] FOREIGN KEY([script_id])
REFERENCES [dbo].[Scripts] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Schedules] CHECK CONSTRAINT [FK_Schedules_Scripts]
GO
ALTER TABLE [dbo].[Schedules]  WITH CHECK ADD  CONSTRAINT [FK_Schedules_Users] FOREIGN KEY([created_by_user_id])
REFERENCES [dbo].[Users] ([id])
GO
ALTER TABLE [dbo].[Schedules] CHECK CONSTRAINT [FK_Schedules_Users]
GO
ALTER TABLE [dbo].[ScriptDependencies]  WITH CHECK ADD  CONSTRAINT [FK_ScriptDep_DependsOn] FOREIGN KEY([depends_on_script_id])
REFERENCES [dbo].[Scripts] ([id])
GO
ALTER TABLE [dbo].[ScriptDependencies] CHECK CONSTRAINT [FK_ScriptDep_DependsOn]
GO
ALTER TABLE [dbo].[ScriptDependencies]  WITH CHECK ADD  CONSTRAINT [FK_ScriptDep_Script] FOREIGN KEY([script_id])
REFERENCES [dbo].[Scripts] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ScriptDependencies] CHECK CONSTRAINT [FK_ScriptDep_Script]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [FK_Executions_Parent] FOREIGN KEY([parent_execution_id])
REFERENCES [dbo].[ScriptExecutions] ([id])
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [FK_Executions_Parent]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [FK_Executions_Schedules] FOREIGN KEY([schedule_id])
REFERENCES [dbo].[Schedules] ([id])
ON DELETE SET NULL
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [FK_Executions_Schedules]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [FK_Executions_Scripts] FOREIGN KEY([script_id])
REFERENCES [dbo].[Scripts] ([id])
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [FK_Executions_Scripts]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [FK_Executions_ScriptVersions] FOREIGN KEY([script_version_id])
REFERENCES [dbo].[ScriptVersions] ([id])
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [FK_Executions_ScriptVersions]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [FK_Executions_Users] FOREIGN KEY([triggered_by_user_id])
REFERENCES [dbo].[Users] ([id])
ON DELETE SET NULL
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [FK_Executions_Users]
GO
ALTER TABLE [dbo].[ScriptParameters]  WITH CHECK ADD  CONSTRAINT [FK_ScriptParameters_Scripts] FOREIGN KEY([script_id])
REFERENCES [dbo].[Scripts] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ScriptParameters] CHECK CONSTRAINT [FK_ScriptParameters_Scripts]
GO
ALTER TABLE [dbo].[ScriptParameters]  WITH CHECK ADD  CONSTRAINT [FK_ScriptParameters_Secrets] FOREIGN KEY([secret_id])
REFERENCES [dbo].[Secrets] ([id])
ON DELETE SET NULL
GO
ALTER TABLE [dbo].[ScriptParameters] CHECK CONSTRAINT [FK_ScriptParameters_Secrets]
GO
ALTER TABLE [dbo].[Scripts]  WITH CHECK ADD  CONSTRAINT [FK_Scripts_Environments] FOREIGN KEY([environment_id])
REFERENCES [dbo].[Environments] ([id])
GO
ALTER TABLE [dbo].[Scripts] CHECK CONSTRAINT [FK_Scripts_Environments]
GO
ALTER TABLE [dbo].[Scripts]  WITH CHECK ADD  CONSTRAINT [FK_Scripts_Users] FOREIGN KEY([created_by_user_id])
REFERENCES [dbo].[Users] ([id])
GO
ALTER TABLE [dbo].[Scripts] CHECK CONSTRAINT [FK_Scripts_Users]
GO
ALTER TABLE [dbo].[ScriptVersions]  WITH CHECK ADD  CONSTRAINT [FK_ScriptVersions_Scripts] FOREIGN KEY([script_id])
REFERENCES [dbo].[Scripts] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ScriptVersions] CHECK CONSTRAINT [FK_ScriptVersions_Scripts]
GO
ALTER TABLE [dbo].[ScriptVersions]  WITH CHECK ADD  CONSTRAINT [FK_ScriptVersions_Users] FOREIGN KEY([created_by_user_id])
REFERENCES [dbo].[Users] ([id])
ON DELETE SET NULL
GO
ALTER TABLE [dbo].[ScriptVersions] CHECK CONSTRAINT [FK_ScriptVersions_Users]
GO
ALTER TABLE [dbo].[Secrets]  WITH CHECK ADD  CONSTRAINT [FK_Secrets_Users] FOREIGN KEY([updated_by_user_id])
REFERENCES [dbo].[Users] ([id])
ON DELETE SET NULL
GO
ALTER TABLE [dbo].[Secrets] CHECK CONSTRAINT [FK_Secrets_Users]
GO
ALTER TABLE [dbo].[SystemSettings]  WITH CHECK ADD  CONSTRAINT [FK_SystemSettings_Environments] FOREIGN KEY([environment_id])
REFERENCES [dbo].[Environments] ([id])
GO
ALTER TABLE [dbo].[SystemSettings] CHECK CONSTRAINT [FK_SystemSettings_Environments]
GO
ALTER TABLE [dbo].[SystemSettings]  WITH CHECK ADD  CONSTRAINT [FK_SystemSettings_Users] FOREIGN KEY([updated_by_user_id])
REFERENCES [dbo].[Users] ([id])
ON DELETE SET NULL
GO
ALTER TABLE [dbo].[SystemSettings] CHECK CONSTRAINT [FK_SystemSettings_Users]
GO
ALTER TABLE [dbo].[ExecutionFiles]  WITH CHECK ADD  CONSTRAINT [CK_ExecutionFiles_type] CHECK  (([file_type]='other' OR [file_type]='png' OR [file_type]='log' OR [file_type]='json' OR [file_type]='txt' OR [file_type]='zip' OR [file_type]='pdf' OR [file_type]='csv' OR [file_type]='xlsx'))
GO
ALTER TABLE [dbo].[ExecutionFiles] CHECK CONSTRAINT [CK_ExecutionFiles_type]
GO
ALTER TABLE [dbo].[ExecutionLogs]  WITH CHECK ADD  CONSTRAINT [CK_ExecutionLogs_level] CHECK  (([log_level]='CRITICAL' OR [log_level]='ERROR' OR [log_level]='WARNING' OR [log_level]='INFO' OR [log_level]='DEBUG'))
GO
ALTER TABLE [dbo].[ExecutionLogs] CHECK CONSTRAINT [CK_ExecutionLogs_level]
GO
ALTER TABLE [dbo].[Schedules]  WITH CHECK ADD  CONSTRAINT [CK_Schedules_retries] CHECK  (([max_retries]>=(0) AND [max_retries]<=(10)))
GO
ALTER TABLE [dbo].[Schedules] CHECK CONSTRAINT [CK_Schedules_retries]
GO
ALTER TABLE [dbo].[Schedules]  WITH CHECK ADD  CONSTRAINT [CK_Schedules_retry_delay] CHECK  (([retry_delay_seconds]>=(0) AND [retry_delay_seconds]<=(86400)))
GO
ALTER TABLE [dbo].[Schedules] CHECK CONSTRAINT [CK_Schedules_retry_delay]
GO
ALTER TABLE [dbo].[Schedules]  WITH CHECK ADD  CONSTRAINT [CK_Schedules_status] CHECK  (([last_status] IS NULL OR ([last_status]='Ejecutando' OR [last_status]='Cancelado' OR [last_status]='Error' OR [last_status]='Exitoso')))
GO
ALTER TABLE [dbo].[Schedules] CHECK CONSTRAINT [CK_Schedules_status]
GO
ALTER TABLE [dbo].[ScriptDependencies]  WITH CHECK ADD  CONSTRAINT [CK_ScriptDependencies_no_self] CHECK  (([script_id]<>[depends_on_script_id]))
GO
ALTER TABLE [dbo].[ScriptDependencies] CHECK CONSTRAINT [CK_ScriptDependencies_no_self]
GO
ALTER TABLE [dbo].[ScriptDependencies]  WITH CHECK ADD  CONSTRAINT [CK_ScriptDependencies_type] CHECK  (([dependency_type]='soft' OR [dependency_type]='hard'))
GO
ALTER TABLE [dbo].[ScriptDependencies] CHECK CONSTRAINT [CK_ScriptDependencies_type]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [CK_Executions_status] CHECK  (([status]='Cancelado' OR [status]='Error' OR [status]='Exitoso' OR [status]='Ejecutando'))
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [CK_Executions_status]
GO
ALTER TABLE [dbo].[ScriptExecutions]  WITH CHECK ADD  CONSTRAINT [CK_Executions_trigger] CHECK  (([trigger_type]='system' OR [trigger_type]='api' OR [trigger_type]='dependency' OR [trigger_type]='schedule' OR [trigger_type]='manual'))
GO
ALTER TABLE [dbo].[ScriptExecutions] CHECK CONSTRAINT [CK_Executions_trigger]
GO
ALTER TABLE [dbo].[ScriptParameters]  WITH CHECK ADD  CONSTRAINT [CK_ScriptParameters_secret_consistency] CHECK  (([is_secret]=(0) AND [param_value] IS NOT NULL OR [is_secret]=(1) AND [secret_id] IS NOT NULL))
GO
ALTER TABLE [dbo].[ScriptParameters] CHECK CONSTRAINT [CK_ScriptParameters_secret_consistency]
GO
ALTER TABLE [dbo].[ScriptParameters]  WITH CHECK ADD  CONSTRAINT [CK_ScriptParameters_type] CHECK  (([param_type]='config' OR [param_type]='argv' OR [param_type]='env'))
GO
ALTER TABLE [dbo].[ScriptParameters] CHECK CONSTRAINT [CK_ScriptParameters_type]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [CK_Users_auth_provider] CHECK  (([auth_provider]='entra_id' OR [auth_provider]='active_directory' OR [auth_provider]='local'))
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [CK_Users_auth_provider]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [CK_Users_password_provider] CHECK  (([auth_provider]='local' AND [password_hash] IS NOT NULL OR ([auth_provider]='entra_id' OR [auth_provider]='active_directory')))
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [CK_Users_password_provider]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [CK_Users_role] CHECK  (([role]='Viewer' OR [role]='Operator' OR [role]='Developer' OR [role]='DataArchitect' OR [role]='Admin'))
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [CK_Users_role]
GO
/****** Objeto: StoredProcedure [dbo].[usp_AddExecutionLog] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[usp_AddExecutionLog]
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
END;
GO
/****** Objeto: StoredProcedure [dbo].[usp_FinishScriptExecution] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_FinishScriptExecution]
    @execution_id INT,
    @status NVARCHAR(20),
    @exit_code INT = NULL,
    @error_message NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.ScriptExecutions
    SET
        status = @status,
        end_time = SYSUTCDATETIME(),
        exit_code = @exit_code,
        error_message = @error_message,
        duration_seconds = DATEDIFF(SECOND, start_time, SYSUTCDATETIME())
    WHERE id = @execution_id;
END;
GO
/****** Objeto: StoredProcedure [dbo].[usp_GetExecutionOrder] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
--  19. Stored procedures operationales
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_GetExecutionOrder]
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
/****** Objeto: StoredProcedure [dbo].[usp_GetSecret] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_GetSecret]
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
/****** Objeto: StoredProcedure [dbo].[usp_InsertSecret] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_InsertSecret]
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
/****** Objeto: StoredProcedure [dbo].[usp_StartScriptExecution] Fecha de script: 01/06/2026 07:13:42 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_StartScriptExecution]
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
        script_id,
        script_version_id,
        schedule_id,
        triggered_by_user_id,
        parent_execution_id,
        trigger_type,
        status,
        command_line,
        working_directory,
        machine_name,
        process_id,
        start_time
    )
    VALUES (
        @script_id,
        @script_version_id,
        @schedule_id,
        @triggered_by_user_id,
        @parent_execution_id,
        @trigger_type,
        'Ejecutando',
        @command_line,
        @working_directory,
        @machine_name,
        @process_id,
        SYSUTCDATETIME()
    );

    SET @execution_id = SCOPE_IDENTITY();
END;
GO
USE [master]
GO
ALTER DATABASE [PyFlowManager] SET  READ_WRITE 
GO