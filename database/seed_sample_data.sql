USE PyFlowManager;
GO

DECLARE @env_id INT = (SELECT id FROM dbo.Environments WHERE name = 'Production');
DECLARE @user_id INT = (SELECT TOP 1 id FROM dbo.Users ORDER BY id);

IF NOT EXISTS (SELECT 1 FROM dbo.Scripts WHERE name = 'sample_etl.py' AND environment_id = @env_id)
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
        author
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
        'Admin_User'
    );
END
GO

SELECT * FROM dbo.vw_ScriptsSummary;
GO
