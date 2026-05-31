// src/services/executionValidationService.ts

import { getPool, sql } from '../db/sql';
import { addExecutionLog } from './dbLogService';

type ValidationStatus = 'OK' | 'WARNING' | 'ERROR';

function normalizeParam(value: any): string {
  if (value === null || value === undefined) return '';
  const text = String(value).trim();
  if (text.toLowerCase() === 'null' || text.toLowerCase() === 'undefined') return '';
  return text;
}

function getDateParam(parameters: Record<string, string>, key: string): string {
  return normalizeParam(parameters[key]);
}

export async function runExecutionValidations(
  executionId: number,
  scriptId: number,
  parameters: Record<string, string>
): Promise<ValidationStatus> {
  const pool = await getPool();

  await addExecutionLog(executionId, 'INFO', '[VALIDATION] Iniciando validaciones post-ejecución.');

  const startDate = getDateParam(parameters, 'START_DATE');
  const endDate = getDateParam(parameters, 'END_DATE');

  if (!startDate) {
    await addExecutionLog(
      executionId,
      'WARNING',
      '[VALIDATION] No se encontró START_DATE. No se ejecutaron validaciones.'
    );

    await saveValidationResult(pool, {
      executionId,
      name: 'Validación general',
      status: 'WARNING',
      totalChecked: 0,
      totalErrors: 0,
      details: 'No se encontró START_DATE en los parámetros de ejecución.'
    });

    return 'WARNING';
  }

  /*
    Validación específica para GNS Estados de Agentes.

    Regla:
    Para cada FECHA + USERID + STARTTIME + METRIC,
    tOrganizationPresence y tSystemPresence deben sumar 1,800,000 ms
    cuando la granularidad es PT30M.
  */

  try {
    const validationResult = await pool.request()
      .input('fecha', sql.Date, startDate)
      .query(`
        SELECT
          COUNT(*) AS total_errors
        FROM (
          SELECT
            FECHA,
            USERID,
            STARTTIME,
            METRIC,
            SUM("SUM") AS TOTAL_MS
          FROM BI_SS.GNS_API_USER_STATUS
          WHERE FECHA = @fecha
            AND METRIC IN ('tOrganizationPresence', 'tSystemPresence')
          GROUP BY
            FECHA,
            USERID,
            STARTTIME,
            METRIC
          HAVING SUM("SUM") <> 1800000
        ) X
      `);

    const totalErrors = Number(validationResult.recordset[0]?.total_errors ?? 0);

    const status: ValidationStatus = totalErrors === 0 ? 'OK' : 'WARNING';

    await saveValidationResult(pool, {
      executionId,
      name: 'Intervalos de presencia Genesys',
      status,
      totalChecked: null,
      totalErrors,
      details:
        totalErrors === 0
          ? `Validación correcta para fecha ${startDate}.`
          : `Se encontraron ${totalErrors} intervalos con diferencia para fecha ${startDate}.`
    });

    await addExecutionLog(
      executionId,
      status === 'OK' ? 'INFO' : 'WARNING',
      totalErrors === 0
        ? `[VALIDATION] OK - Intervalos de presencia completos para ${startDate}.`
        : `[VALIDATION] WARNING - ${totalErrors} intervalos con diferencias para ${startDate}.`
    );

    return status;
  } catch (error: any) {
    const msg = error?.message || String(error);

    await saveValidationResult(pool, {
      executionId,
      name: 'Intervalos de presencia Genesys',
      status: 'ERROR',
      totalChecked: null,
      totalErrors: null,
      details: msg
    });

    await addExecutionLog(
      executionId,
      'ERROR',
      `[VALIDATION] ERROR - No se pudo ejecutar validación: ${msg}`
    );

    return 'ERROR';
  }
}

async function saveValidationResult(
  pool: any,
  data: {
    executionId: number;
    name: string;
    status: ValidationStatus;
    totalChecked: number | null;
    totalErrors: number | null;
    details: string;
  }
): Promise<void> {
  await pool.request()
    .input('execution_id', sql.Int, data.executionId)
    .input('validation_name', sql.NVarChar(200), data.name)
    .input('validation_status', sql.NVarChar(20), data.status)
    .input('total_checked', sql.Int, data.totalChecked)
    .input('total_errors', sql.Int, data.totalErrors)
    .input('details', sql.NVarChar(sql.MAX), data.details)
    .query(`
      INSERT INTO dbo.ExecutionValidations (
        execution_id,
        validation_name,
        validation_status,
        total_checked,
        total_errors,
        details
      )
      VALUES (
        @execution_id,
        @validation_name,
        @validation_status,
        @total_checked,
        @total_errors,
        @details
      )
    `);
}