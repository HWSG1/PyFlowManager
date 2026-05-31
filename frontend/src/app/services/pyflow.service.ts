
import { Injectable, computed, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Script, Execution, Schedule, Toast, TabName, EnvParam } from '../models/models';

function formatDate(value: any): string {
  if (!value) return 'Nunca';

  const str = String(value);

  const match = str.match(
    /^(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})/
  );

  if (!match) {
    return str;
  }

  const [, year, month, day, hourStr, minute] = match;

  let hour = Number(hourStr);

  const ampm = hour >= 12 ? 'p. m.' : 'a. m.';

  hour = hour % 12;

  if (hour === 0) {
    hour = 12;
  }

  return `${day}/${month}/${year}, ${hour.toString().padStart(2, '0')}:${minute} ${ampm}`;
}

function formatDuration(seconds: any): string {
  if (seconds === null || seconds === undefined || isNaN(Number(seconds))) return '--';
  const s = Number(seconds);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}m ${r}s`;
}

@Injectable({ providedIn: 'root' })
export class PyflowService {
  private apiUrl = '/api';

  activeTab = signal<TabName>('dashboard');
  selectedScript = signal<Script | null>(null);
  toasts = signal<Toast[]>([]);
  showImportModal = signal(false);
  toastCounter = 0;

  scripts = signal<Script[]>([]);
  executions = signal<Execution[]>([]);
  schedules = signal<Schedule[]>([]);
  envParams = signal<EnvParam[]>([]);
  selectedExecutionParameters = signal<any[]>([]);
  showExecutionParametersModal = signal(false);
  editingScheduleId = signal<number | null>(null);
  editingScheduleData = signal<any>(null);

  runningExecutions = computed(() => this.executions().filter(e => e.status === 'Ejecutando').length);
  totalScripts = computed(() => this.scripts().length);
  activeScripts = computed(() => this.scripts().filter(s => s.status === 'active').length);
  errorScripts = computed(() => this.scripts().filter(s => s.lastStatus === 'Error').length);

  constructor(private http: HttpClient) {
    this.refreshAll();
  }

  uploadScript(
    file: File,
    name: string,
    description: string,
    category: string
  ) {
    const formData = new FormData();

    formData.append('file', file);
    formData.append('name', name);
    formData.append('description', description);
    formData.append('category', category);
    formData.append('version', '1.0.0');

    return this.http.post(`${this.apiUrl}/scripts`, formData);
  }

  refreshAll() {
    this.loadScripts();
    this.loadExecutions();
    this.loadSchedules();
    this.loadSettings();
  }

  loadScripts() {
    this.http.get<any[]>(`${this.apiUrl}/scripts`).subscribe({
      next: rows => this.scripts.set(rows.map(this.mapScript)),
      error: err => this.showToast(`Error cargando scripts: ${err?.error?.message || err.message}`, 'error')
    });
  }

  loadExecutions() {
    this.http.get<any[]>(`${this.apiUrl}/executions`).subscribe({
      next: rows => this.executions.set(rows.map(this.mapExecution)),
      error: err => this.showToast(`Error cargando ejecuciones: ${err?.error?.message || err.message}`, 'error')
    });
  }

  loadSchedules() {
    this.http.get<any[]>(`${this.apiUrl}/schedules`).subscribe({
      next: rows => this.schedules.set(rows.map(this.mapSchedule)),
      error: err => this.showToast(`Error cargando schedules: ${err?.error?.message || err.message}`, 'error')
    });
  }

  loadSettings() {
    this.http.get<any>(`${this.apiUrl}/settings`).subscribe({
      next: data => {
        const vars = (data?.globalVars || []).map((x: any) => ({
          id: x.id,
          key: x.var_key,
          value: x.var_value,
          isSecret: !!x.is_secret,
          description: x.description || ''
        }));

        this.envParams.set(vars);
      },
      error: () => {}
    });
  }

  mapScript(row: any): Script {
    return {
      id: row.id,
      name: row.name,
      category: row.category || 'ETL',
      path: row.file_path || '',
      status: row.is_active ? 'active' : 'inactive',
      lastRun: formatDate(row.last_execution_start_time),
      nextRun: formatDate(row.next_run_at),
      lastStatus: row.last_execution_status || 'Nunca',
      description: row.description || '',
      author: row.created_by || 'Admin_User',
      version: row.current_version || '1.0.0',
      successCount: row.total_success || 0,
      errorCount: row.total_errors || 0,
      avgDuration: formatDuration(row.last_duration_seconds)
    };
  }

  mapExecution(row: any): Execution {
    return {
      id: `EX-${row.id}`,
      script: row.script_name,
      status: row.status,
      start: formatDate(row.start_time),
      end: row.end_time ? formatDate(row.end_time) : '--',
      duration: formatDuration(row.duration_seconds),
      user: row.triggered_by || 'Sistema',
      message: row.error_message || row.trigger_type || ''
    };
  }

  mapSchedule(row: any): Schedule {
    return {
      id: row.id,
      scriptId: row.script_id,
      scriptName: row.script_name,
      frequency: row.frequency_label || 'Personalizado',
      cronExpression: row.cron_expression || '',
      nextRun: formatDate(row.next_run_at),
      status: row.is_active ? 'active' : 'paused'
    };
  }

  switchTab(tab: TabName) {
    this.activeTab.set(tab);
  }

  openScriptDetail(script: Script) {
    this.selectedScript.set(script);
    this.activeTab.set('script-detail');
  }

  addScript(partial: Partial<Script>) {
    const scriptName = partial.name || 'new_script.py';

    const payload = {
      name: scriptName,
      category: partial.category || 'ETL',
      description: partial.description || 'Sin descripción.',
      file_path: (partial as any).file_path || partial.path || `runtime/scripts/${scriptName}`,
      path: (partial as any).file_path || partial.path || `runtime/scripts/${scriptName}`,
      version: partial.version || '1.0.0'
    };

    this.http.post(`${this.apiUrl}/scripts`, payload).subscribe({
      next: () => {
        this.showToast('Script registrado correctamente.');
        this.loadScripts();
      },
      error: err =>
        this.showToast(
          `Error registrando script: ${err?.error?.message || err.message}`,
          'error'
        )
    });
  }
  toggleScriptStatus(id: number) {
    this.http.patch(`${this.apiUrl}/scripts/${id}/toggle`, {}).subscribe({
      next: () => {
        this.showToast('Estado del script actualizado.', 'info');
        this.loadScripts();
      },
      error: err => this.showToast(`Error actualizando estado: ${err?.error?.message || err.message}`, 'error')
    });
  }

  deleteScript(id: number) {
    this.http.delete(`${this.apiUrl}/scripts/${id}`).subscribe({
      next: () => {
        this.showToast('Script desactivado.', 'warning');
        this.loadScripts();
      },
      error: err => this.showToast(`Error eliminando script: ${err?.error?.message || err.message}`, 'error')
    });
  }

  addSchedule(schedule: Partial<Schedule>) {
    this.http.post(`${this.apiUrl}/schedules`, schedule).subscribe({
      next: () => {
        this.showToast('Programación guardada.');
        this.loadSchedules();
        this.loadScripts();
      },
      error: err => this.showToast(`Error guardando programación: ${err?.error?.message || err.message}`, 'error')
    });
  }

  deleteSchedule(id: number) {
    this.http.delete(`${this.apiUrl}/schedules/${id}`).subscribe({
      next: () => {
        this.showToast('Programación desactivada.', 'info');
        this.loadSchedules();
      },
      error: err => this.showToast(`Error eliminando programación: ${err?.error?.message || err.message}`, 'error')
    });
  }

  executeScript(script: Script, parameters: Record<string, string> = {}) {
    this.showToast(`Ejecutando: ${script.name}`, 'info');

    this.http.post<any>(`${this.apiUrl}/scripts/${script.id}/run`, {
      parameters
    }).subscribe({
      next: result => {
        this.showToast(`Ejecución iniciada: EX-${result.executionId}`, 'info');
        this.loadExecutions();
        this.watchExecution(result.executionId);
      },
      error: err => this.showToast(`Error ejecutando script: ${err?.error?.message || err.message}`, 'error')
    });
  }

  watchExecution(executionId: number) {
    const source = new EventSource(`${this.apiUrl}/executions/${executionId}/stream`);

    source.onmessage = (event) => {
      const payload = JSON.parse(event.data);
      if (payload.done) {
        this.showToast(`Ejecución EX-${executionId}: ${payload.status}`, payload.status === 'Exitoso' ? 'success' : 'error');
        source.close();
        this.loadExecutions();
        this.loadScripts();
      }
    };

    source.onerror = () => {
      source.close();
    };
  }

  getExecutionLogs(executionId: string | number) {
    const id = String(executionId).replace('EX-', '');
    return this.http.get<any[]>(`${this.apiUrl}/executions/${id}/logs`);
  }

  getExecutionParameters(executionId: string | number) {
    const id = String(executionId).replace('EX-', '');

    return this.http.get<any[]>(
      `${this.apiUrl}/executions/${id}/parameters`
    );
  }

  openExecutionParameters(executionId: string | number) {
    this.getExecutionParameters(executionId).subscribe({
      next: rows => {
        this.selectedExecutionParameters.set(rows || []);
        this.showExecutionParametersModal.set(true);
      },
      error: err => {
        this.showToast(
          `Error cargando parámetros: ${err?.error?.message || err.message}`,
          'error'
        );
      }
    });
  }

  showToast(message: string, type: Toast['type'] = 'success') {
    const id = ++this.toastCounter;
    this.toasts.update(t => [...t, { id, message, type }]);
    setTimeout(() => this.removeToast(id), 4000);
  }

  removeToast(id: number) {
    this.toasts.update(t => t.filter(toast => toast.id !== id));
  }

  cancelExecution(executionId: number) {
    return this.http.post(`${this.apiUrl}/scripts/executions/${executionId}/cancel`, {});
  }

  getScriptParameters(scriptId: number) {
    return this.http.get<any[]>(`${this.apiUrl}/scripts/${scriptId}/parameters`);
  }

  toggleScheduleStatus(id: number) {
    this.http.patch(`${this.apiUrl}/schedules/${id}/toggle`, {}).subscribe({
      next: () => {
        this.showToast('Estado de la programación actualizado.', 'info');
        this.loadSchedules();
        this.loadScripts();
      },
      error: err =>
        this.showToast(
          `Error actualizando programación: ${err?.error?.message || err.message}`,
          'error'
        )
    });
  }

  getSchedule(id: number) {
    return this.http.get<any>(
      `${this.apiUrl}/schedules/${id}`
    );
  }

  loadScheduleForEdit(id: number) {
    this.getSchedule(id).subscribe({
      next: data => {
        this.editingScheduleId.set(id);
        this.editingScheduleData.set(data);
      },
      error: err => {
        this.showToast(
          `Error cargando programación: ${err?.error?.message || err.message}`,
          'error'
        );
      }
    });
  }

  updateSchedule(
    id: number,
    payload: any
  ) {
    return this.http.put(
      `${this.apiUrl}/schedules/${id}`,
      payload
    );
  }

  clearEditingSchedule() {
    this.editingScheduleId.set(null);
    this.editingScheduleData.set(null);
  }


  saveGlobalVariables(variables: any[]) {
    return this.http.post(`${this.apiUrl}/settings/global-variables`, {
      variables
    });
  }

  deleteGlobalVariable(id: number) {
    return this.http.delete(`${this.apiUrl}/settings/global-variables/${id}`);
  }
  
}
