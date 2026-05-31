# PyFlow Manager Functional

Proyecto funcional basado en el mockup Angular cargado por el usuario, conectado a SQL Server y con backend Node.js para administrar y ejecutar scripts Python.

## Stack

- Frontend: Angular 17
- Backend: Node.js + Express + TypeScript
- Base de datos: SQL Server 2025 Developer / SQL Server Standard compatible
- Ejecución scripts: `child_process.spawn`
- Logs en tiempo real: Server-Sent Events (SSE)

## Estructura

```text
pyflow-manager-functional/
  frontend/
  backend/
  database/
  runtime/
    scripts/
    logs/
    exports/
```

## 1. Crear base de datos

Ejecutá en SQL Server Management Studio:

```sql
database/pyflow_database_sqlserver_recomendado_v3.sql
```

El script crea la base:

```text
PyFlowManager
```

## 2. Configurar backend

```powershell
cd backend
copy .env.example .env
npm install
npm run dev
```

Editá `.env` con tu SQL Server:

```env
DB_SERVER=localhost
DB_PORT=1433
DB_DATABASE=PyFlowManager
DB_USER=sa
DB_PASSWORD=tu_password
DB_ENCRYPT=false
DB_TRUST_SERVER_CERTIFICATE=true
```

## 3. Configurar frontend

```powershell
cd frontend
npm install
npm start
```

Abrir:

```text
http://localhost:4200
```

## 4. Cargar script de prueba

El backend incluye:

```text
backend/scripts/sample_etl.py
```

Registralo en SQL con file_path absoluto o copiá tus scripts a:

```text
runtime/scripts/
```

## 5. Endpoints principales

```text
GET    /api/health
GET    /api/scripts
POST   /api/scripts
PATCH  /api/scripts/:id/toggle
DELETE /api/scripts/:id
POST   /api/scripts/:id/run
GET    /api/executions
GET    /api/executions/:id/logs
GET    /api/executions/:id/stream
GET    /api/schedules
POST   /api/schedules
DELETE /api/schedules/:id
GET    /api/settings
```

## Nota importante

Para ejecutar scripts reales, el `file_path` debe existir en el servidor donde corre el backend.

Ejemplo:

```text
C:\Users\ojumanzor\Documents\Análisis\Python\KNIME to Python\GNS Usuarios.py
```
