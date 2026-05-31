import { Component, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PyflowService } from '../../services/pyflow.service';
import { Script } from '../../models/models';

@Component({
  selector: 'app-scripts',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="flex flex-col gap-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-white">Scripts Administrados</h1>
          <p class="text-sm text-slate-400">Sube, configura y arranca tus tareas de Python directamente.</p>
        </div>
        <button (click)="svc.showImportModal.set(true)"
                class="bg-blue-600 hover:bg-blue-500 text-white font-semibold text-sm px-4 py-2 rounded-lg flex items-center gap-2 shadow-lg transition-all">
          ↑ Importar Script
        </button>
      </div>

      <!-- Filters -->
      <div class="bg-slate-950 border border-slate-800 p-4 rounded-xl flex flex-wrap gap-4 items-center justify-between">
        <div class="flex flex-wrap items-center gap-3">
          <div class="relative w-64">
            <input type="text" [(ngModel)]="searchTerm" placeholder="Buscar script por nombre..."
                   class="w-full bg-slate-900 border border-slate-800 rounded-lg pl-4 pr-4 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-blue-500">
          </div>
          <select [(ngModel)]="filterCategory" class="bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-300 focus:outline-none focus:border-blue-500">
            <option value="all">Todas las Categorías</option>
            <option value="BI & Analytics">BI & Analytics</option>
            <option value="ETL Pipeline">ETL Pipeline</option>
            <option value="Database Sync">Database Sync</option>
            <option value="Notificaciones">Notificaciones</option>
          </select>
          <select [(ngModel)]="filterStatus" class="bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-300 focus:outline-none focus:border-blue-500">
            <option value="all">Todos los Estados</option>
            <option value="active">Activos</option>
            <option value="inactive">Inactivos</option>
          </select>
        </div>
        <div class="text-xs text-slate-400">
          Total: <span class="text-blue-400 font-bold">{{ filteredScripts.length }}</span>
        </div>
      </div>

      <!-- Table -->
      <div class="bg-slate-950 border border-slate-800 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-slate-300">
            <thead class="bg-slate-900/60 text-xs font-semibold uppercase text-slate-400 border-b border-slate-800">
              <tr>
                <th class="px-6 py-3.5">Nombre</th>
                <th class="px-6 py-3.5">Categoría</th>
                <th class="px-6 py-3.5">Ruta Archivo</th>
                <th class="px-6 py-3.5">Estado</th>
                <th class="px-6 py-3.5">Última Ejecución</th>
                <th class="px-6 py-3.5">Próxima Ejecución</th>
                <th class="px-6 py-3.5 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              @for (script of filteredScripts; track script.id) {
                <tr class="hover:bg-slate-900/40 text-xs">
                  <td class="px-6 py-3.5">
                    <div class="flex items-center gap-2">
                      <span class="code-font font-semibold text-blue-300">{{ script.name }}</span>
                    </div>
                    <p class="text-[10px] text-slate-500 mt-0.5 truncate max-w-[180px]">{{ script.description }}</p>
                  </td>
                  <td class="px-6 py-3.5">
                    <span class="px-2 py-0.5 rounded-full text-[10px] bg-slate-900 border border-slate-800 text-slate-300 font-medium">{{ script.category }}</span>
                  </td>
                  <td class="px-6 py-3.5 code-font text-slate-500 text-[10px]">{{ script.path }}</td>
                  <td class="px-6 py-3.5">
                    <span [class]="script.status === 'active' ? 'px-2 py-0.5 rounded-full text-[10px] bg-emerald-950 border border-emerald-900 text-emerald-400 font-medium' : 'px-2 py-0.5 rounded-full text-[10px] bg-slate-800 border border-slate-700 text-slate-400 font-medium'">
                      {{ script.status === 'active' ? 'Activo' : 'Inactivo' }}
                    </span>
                  </td>
                  <td class="px-6 py-3.5 text-slate-500">
                    {{ script.lastRun }}
                    <span [class]="lastStatusBadge(script.lastStatus)" class="ml-2">{{ script.lastStatus }}</span>
                  </td>
                  <td class="px-6 py-3.5 text-slate-400">{{ script.nextRun }}</td>
                  <td class="px-6 py-3.5 text-right">
                    <div class="flex items-center justify-end gap-2">
                      <button (click)="svc.openScriptDetail(script)" class="text-blue-500 hover:text-blue-400 font-semibold">Ver</button>
                      <button (click)="svc.executeScript(script)" class="text-emerald-500 hover:text-emerald-400 font-semibold">Ejecutar</button>
                      <button (click)="svc.toggleScriptStatus(script.id)" class="text-amber-500 hover:text-amber-400 font-semibold">
                        {{ script.status === 'active' ? 'Pausar' : 'Activar' }}
                      </button>
                      <button (click)="svc.deleteScript(script.id)" class="text-rose-500 hover:text-rose-400 font-semibold">Eliminar</button>
                    </div>
                  </td>
                </tr>
              }
              @empty {
                <tr>
                  <td colspan="7" class="px-6 py-10 text-center text-slate-500 text-xs">
                    No se encontraron scripts con los filtros actuales.
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `
})
export class ScriptsComponent {
  searchTerm = '';
  filterCategory = 'all';
  filterStatus = 'all';

  constructor(public svc: PyflowService) {}

  get filteredScripts(): Script[] {
    return this.svc.scripts().filter(s => {
      const matchName = s.name.toLowerCase().includes(this.searchTerm.toLowerCase());
      const matchCat = this.filterCategory === 'all' || s.category === this.filterCategory;
      const matchStatus = this.filterStatus === 'all' || s.status === this.filterStatus;
      return matchName && matchCat && matchStatus;
    });
  }

  lastStatusBadge(status: string): string {
    const map: Record<string, string> = {
      'Exitoso': 'px-1.5 py-0.5 rounded text-[9px] bg-emerald-950 text-emerald-400',
      'Error': 'px-1.5 py-0.5 rounded text-[9px] bg-rose-950 text-rose-400',
      'Ejecutando': 'px-1.5 py-0.5 rounded text-[9px] bg-blue-950 text-blue-400',
      'Cancelado': 'px-1.5 py-0.5 rounded text-[9px] bg-slate-800 text-slate-400',
      'Nunca': 'px-1.5 py-0.5 rounded text-[9px] bg-slate-800 text-slate-500',
    };
    return map[status] ?? map['Nunca'];
  }
}
