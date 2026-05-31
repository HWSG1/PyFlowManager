import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PyflowService } from '../../services/pyflow.service';
import { Execution } from '../../models/models';

@Component({
  selector: 'app-logs',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="flex flex-col gap-6">

      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-white">
            Logs e Histórico de Ejecución
          </h1>

          <p class="text-sm text-slate-400">
            Analiza el histórico general de todas las ejecuciones de procesos del sistema.
          </p>
        </div>

        <button
          (click)="exportLogs()"
          class="bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 font-semibold text-xs px-4 py-2 rounded-lg flex items-center gap-1.5 transition-all">
          ↓ Exportar Historial (.txt)
        </button>
      </div>

      <!-- Filters -->
      <div class="bg-slate-950 border border-slate-800 p-4 rounded-xl grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">

        <div>
          <label class="text-[10px] text-slate-400 font-bold uppercase block mb-1">
            Filtrar por Script
          </label>

          <select
            [(ngModel)]="filterScript"
            class="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-300">

            <option value="all">Todos los scripts</option>

            @for (s of svc.scripts(); track s.id) {
              <option [value]="s.name">
                {{ s.name }}
              </option>
            }

          </select>
        </div>

        <div>
          <label class="text-[10px] text-slate-400 font-bold uppercase block mb-1">
            Filtrar por Estado
          </label>

          <select
            [(ngModel)]="filterStatus"
            class="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-300">

            <option value="all">Todos los estados</option>
            <option value="Exitoso">Exitoso</option>
            <option value="Error">Error</option>
            <option value="Ejecutando">Ejecutando</option>
            <option value="Cancelado">Cancelado</option>

          </select>
        </div>

        <div>
          <label class="text-[10px] text-slate-400 font-bold uppercase block mb-1">
            Filtrar por Usuario
          </label>

          <select
            [(ngModel)]="filterUser"
            class="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-300">

            <option value="all">Todos los usuarios</option>
            <option value="Sistema (Auto)">Sistema (Auto)</option>
            <option value="Admin_User">Admin_User</option>

          </select>
        </div>

        <div class="flex items-end">
          <button
            (click)="resetFilters()"
            class="w-full bg-slate-900 hover:bg-slate-800 text-slate-400 hover:text-white border border-slate-800 rounded-lg py-1.5 text-xs font-semibold transition-all">

            Limpiar Filtros

          </button>
        </div>

      </div>

      <!-- Tabla -->
      <div class="bg-slate-950 border border-slate-800 rounded-xl overflow-hidden">

        <div class="overflow-x-auto">

          <table class="w-full text-left text-sm text-slate-300">

            <thead class="bg-slate-900/60 text-xs font-semibold uppercase text-slate-400 border-b border-slate-800">
              <tr>
                <th class="px-6 py-3.5">ID Ejecución</th>
                <th class="px-6 py-3.5">Script</th>
                <th class="px-6 py-3.5">Estado</th>
                <th class="px-6 py-3.5">Inicio</th>
                <th class="px-6 py-3.5">Fin</th>
                <th class="px-6 py-3.5">Duración</th>
                <th class="px-6 py-3.5">Mensaje Final</th>
                <th class="px-6 py-3.5 text-right">Acción</th>
              </tr>
            </thead>

            <tbody class="divide-y divide-slate-800/60">

              @for (ex of filteredExecutions; track ex.id) {

                <tr class="hover:bg-slate-900/40 text-xs text-slate-300">

                  <td class="px-6 py-3.5 font-semibold text-slate-400 code-font">
                    {{ ex.id }}
                  </td>

                  <td class="px-6 py-3.5 font-bold text-white">
                    {{ ex.script }}
                  </td>

                  <td class="px-6 py-3.5">
                    <span [class]="statusBadge(ex.status)">
                      {{ ex.status }}
                    </span>
                  </td>

                  <td class="px-6 py-3.5 text-slate-500">
                    {{ ex.start }}
                  </td>

                  <td class="px-6 py-3.5 text-slate-500">
                    {{ ex.end }}
                  </td>

                  <td class="px-6 py-3.5 font-semibold">
                    {{ ex.duration }}
                  </td>

                  <td
                    class="px-6 py-3.5 text-slate-500 max-w-[200px] truncate"
                    [title]="ex.message">

                    {{ ex.message }}

                  </td>

                  <td class="px-6 py-3.5 text-right">

                    <div class="flex gap-3 justify-end">

                      <button
                        (click)="svc.openExecutionParameters(ex.id)"
                        class="text-emerald-500 hover:text-emerald-400 font-semibold">

                        Parámetros

                      </button>

                      <button
                        (click)="viewLog(ex)"
                        class="text-blue-500 hover:text-blue-400 font-semibold">

                        Abrir Log

                      </button>

                    </div>

                  </td>

                </tr>

              }

              @empty {

                <tr>

                  <td
                    colspan="8"
                    class="px-6 py-10 text-center text-slate-500 text-xs">

                    No hay registros con los filtros actuales.

                  </td>

                </tr>

              }

            </tbody>

          </table>

        </div>

      </div>

      <!-- Modal Parámetros -->

      @if (svc.showExecutionParametersModal()) {

        <div class="fixed inset-0 bg-black/70 flex items-center justify-center z-50">

          <div class="w-[700px] max-h-[80vh] overflow-hidden bg-slate-950 border border-slate-800 rounded-xl">

            <div class="px-5 py-4 border-b border-slate-800 flex items-center justify-between">

              <h3 class="text-white font-semibold">
                Parámetros de la Ejecución
              </h3>

              <button
                (click)="svc.showExecutionParametersModal.set(false)"
                class="text-slate-400 hover:text-white">

                ✕

              </button>

            </div>

            <div class="max-h-[500px] overflow-auto">

              <table class="w-full text-xs">

                <thead class="bg-slate-900 text-slate-400 uppercase">

                  <tr>
                    <th class="px-4 py-3 text-left">Parámetro</th>
                    <th class="px-4 py-3 text-left">Valor</th>
                  </tr>

                </thead>

                <tbody>

                  @for (
                    p of svc.selectedExecutionParameters();
                    track p.id
                  ) {

                    <tr class="border-t border-slate-800">

                      <td class="px-4 py-3 text-blue-400 code-font">
                        {{ p.param_key }}
                      </td>

                      <td class="px-4 py-3 text-slate-300 code-font break-all">
                        {{ p.param_value }}
                      </td>

                    </tr>

                  }

                </tbody>

              </table>

            </div>

          </div>

        </div>

      }

    </div>
  `
})
export class LogsComponent {
  filterScript = 'all';
  filterStatus = 'all';
  filterUser = 'all';

  constructor(public svc: PyflowService) {}

  get filteredExecutions(): Execution[] {
    return this.svc.executions().filter(e => {
      const matchScript = this.filterScript === 'all' || e.script === this.filterScript;
      const matchStatus = this.filterStatus === 'all' || e.status === this.filterStatus;
      const matchUser = this.filterUser === 'all' || e.user === this.filterUser;
      return matchScript && matchStatus && matchUser;
    });
  }

  resetFilters() {
    this.filterScript = 'all';
    this.filterStatus = 'all';
    this.filterUser = 'all';
  }

  viewLog(ex: Execution) {
    const target = this.svc.scripts().find(s => s.name === ex.script);
    if (target) {
      this.svc.openScriptDetail(target);
      this.svc.showToast(`Log ${ex.id} cargado en consola.`);
    }
  }

  exportLogs() {
    let content = '=== PYFLOW MANAGER LOG EXPORT ===\n\n';
    this.svc.executions().forEach(ex => {
      content += `ID: ${ex.id} | Script: ${ex.script} | Status: ${ex.status} | Start: ${ex.start} | Duration: ${ex.duration}\nMessage: ${ex.message}\n---\n`;
    });
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `pyflow_logs_${new Date().toISOString().slice(0, 10)}.txt`;
    a.click();
    this.svc.showToast('Historial exportado como .txt');
  }

  statusBadge(status: string): string {
    const map: Record<string, string> = {
      'Exitoso': 'px-2 py-0.5 rounded-full text-[10px] bg-emerald-950 border border-emerald-900 text-emerald-400 font-medium',
      'Error': 'px-2 py-0.5 rounded-full text-[10px] bg-rose-950 border border-rose-900 text-rose-400 font-medium',
      'Ejecutando': 'px-2 py-0.5 rounded-full text-[10px] bg-blue-950 border border-blue-900 text-blue-400 font-medium',
      'Cancelado': 'px-2 py-0.5 rounded-full text-[10px] bg-slate-900 border border-slate-800 text-slate-400 font-medium',
    };
    return map[status] ?? map['Cancelado'];
  }
}
