-- ============================================================
--  PyFlowManager - Datos iniciales (seed)
--  Versión corregida — Junio 2026
--
--  Incluye: ambiente Production, usuario Admin, y script de ejemplo
--  Ejecutar DESPUÉS del script principal de base de datos
-- ============================================================

USE PyFlowManager;
GO

-- ============================================================
--  1. Ambiente base
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.Environments WHERE name = 'Production')
BEGIN
    INSERT INTO dbo.Environments (name, description, is_active)
    VALUES ('Production', 'Ambiente de producción', 1);
    PRINT 'Ambiente Production creado.';
END
ELSE
    PRINT 'Ambiente Production ya existe.';
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Environments WHERE name = 'Development')
BEGIN
    INSERT INTO dbo.Environments (name, description, is_active)
    VALUES ('Development', 'Ambiente de desarrollo', 1);
    PRINT 'Ambiente Development creado.';
END
GO

-- ============================================================
--  2. Usuario Admin inicial
--  ► Cambia el password_hash antes de usar en producción.
--    El valor de ejemplo es un placeholder SHA-512.
--    Asegúrate de almacenar un hash real generado por tu app.
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE username = 'admin')
BEGIN
    INSERT INTO dbo.Users (
        username,
        email,
        display_name,
        auth_provider,
        password_hash,
        role,
        is_active
    )
    VALUES (
        'admin',
        'admin@empresa.com',
        'Administrador',
        'local',
        -- ► REEMPLAZAR con hash real (bcrypt/SHA-512) generado por la app
        'PLACEHOLDER_HASH_CAMBIAR_ANTES_DE_USAR',
        'Admin',
        1
    );
    PRINT 'Usuario admin creado.';
END
ELSE
    PRINT 'Usuario admin ya existe.';
GO

-- ============================================================
--  3. Script de ejemplo
-- ============================================================
DECLARE @env_id  INT = (SELECT id FROM dbo.Environments WHERE name = 'Production');
DECLARE @user_id INT = (SELECT id FROM dbo.Users WHERE username = 'admin');

IF @env_id IS NULL
BEGIN
    RAISERROR('ERROR: No se encontró el ambiente Production. Verifica el paso anterior.', 16, 1);
    RETURN;
END

IF @user_id IS NULL
BEGIN
    RAISERROR('ERROR: No se encontró el usuario admin. Verifica el paso anterior.', 16, 1);
    RETURN;
END

IF NOT EXISTS (
    SELECT 1 FROM dbo.Scripts
    WHERE name = 'sample_etl.py' AND environment_id = @env_id
)
BEGIN
    INSERT INTO dbo.Scripts (
        created_by_user_id,
        environment_id,
        name,
        description,
        category,
        current_version,
        file_path,
        working_directory,
        python_interpreter,
        author,
        is_active,
        allow_manual_run
    )
    VALUES (
        @user_id,
        @env_id,
        'sample_etl.py',
        'Script de prueba incluido en backend/scripts.',
        'ETL Pipeline',
        '1.0.0',
        'sample_etl.py',
        NULL,
        'py',
        'Admin_User',
        1,
        1
    );
    PRINT 'Script sample_etl.py creado.';
END
ELSE
    PRINT 'Script sample_etl.py ya existe.';
GO

-- ============================================================
--  4. Verificación final
-- ============================================================
SELECT 'Environments' AS Tabla, COUNT(*) AS Total FROM dbo.Environments
UNION ALL
SELECT 'Users',   COUNT(*) FROM dbo.Users
UNION ALL
SELECT 'Scripts', COUNT(*) FROM dbo.Scripts;
GO

SELECT * FROM dbo.vw_ScriptsSummary;
GO