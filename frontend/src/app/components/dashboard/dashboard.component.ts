import { Component, OnInit, AfterViewInit, ElementRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { PyflowService } from '../../services/pyflow.service';
import { Chart, registerables } from 'chart.js';
Chart.register(...registerables);

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex flex-col gap-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-white">Dashboard Principal</h1>
          <p class="text-sm text-slate-400">Resumen y estado operacional de tus tareas Python hoy.</p>
        </div>
        <div class="flex items-center gap-2 bg-slate-950 border border-slate-800 px-3 py-1.5 rounded-lg text-xs">
          <span class="text-slate-400">Última actualización:</span>
          <span class="text-blue-400 font-semibold">{{ lastUpdate }}</span>
          <button (click)="refresh()" class="text-slate-400 hover:text-white ml-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/>
              <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- KPI Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
        <!-- Scripts Activos -->
        <div class="bg-slate-950 border border-slate-800/80 p-4 rounded-xl flex items-center justify-between shadow-md relative overflow-hidden group">
          <div class="absolute -right-4 -bottom-4 text-blue-500/10 group-hover:scale-110 transition-transform">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-24 h-24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          </div>
          <div>
            <p class="text-xs font-bold text-slate-400 tracking-wider uppercase mb-1">Scripts Activos</p>
            <h3 class="text-2xl font-bold text-slate-100">{{ activeScripts }} / {{ totalScripts }}</h3>
            <p class="text-[10px] text-emerald-400 mt-2 flex items-center gap-1">▲ +3 nuevos este mes</p>
          </div>
          <div class="bg-blue-500/10 p-3 rounded-xl text-blue-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          </div>
        </div>

        <!-- Éxitos -->
        <div class="bg-slate-950 border border-slate-800/80 p-4 rounded-xl flex items-center justify-between shadow-md relative overflow-hidden group">
          <div class="absolute -right-4 -bottom-4 text-emerald-500/10 group-hover:scale-110 transition-transform">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-24 h-24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
          </div>
          <div>
            <p class="text-xs font-bold text-slate-400 tracking-wider uppercase mb-1">Éxitos Hoy</p>
            <h3 class="text-2xl font-bold text-emerald-400">234</h3>
            <p class="text-[10px] text-slate-400 mt-2">Tasa de éxito <strong class="text-emerald-400">97.5%</strong></p>
          </div>
          <div class="bg-emerald-500/10 p-3 rounded-xl text-emerald-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
          </div>
        </div>

        <!-- Errores -->
        <div class="bg-slate-950 border border-slate-800/80 p-4 rounded-xl flex items-center justify-between shadow-md relative overflow-hidden group">
          <div class="absolute -right-4 -bottom-4 text-rose-500/10 group-hover:scale-110 transition-transform">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-24 h-24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><polygon points="7.86 2 16.14 2 22 7.86 22 16.14 16.14 22 7.86 22 2 16.14 2 7.86 7.86 2"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          </div>
          <div>
            <p class="text-xs font-bold text-slate-400 tracking-wider uppercase mb-1">Errores Hoy</p>
            <h3 class="text-2xl font-bold text-rose-400">6</h3>
            <p class="text-[10px] text-rose-400 mt-2 flex items-center gap-1">⚠ Requiere atención</p>
          </div>
          <div class="bg-rose-500/10 p-3 rounded-xl text-rose-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="7.86 2 16.14 2 22 7.86 22 16.14 16.14 22 7.86 22 2 16.14 2 7.86 7.86 2"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          </div>
        </div>

        <!-- En Ejecución -->
        <div class="bg-slate-950 border border-slate-800/80 p-4 rounded-xl flex items-center justify-between shadow-md relative overflow-hidden group">
          <div>
            <p class="text-xs font-bold text-slate-400 tracking-wider uppercase mb-1">En Ejecución</p>
            <h3 class="text-2xl font-bold text-blue-400">{{ runningCount }}</h3>
            <p class="text-[10px] text-slate-400 mt-2">Consumo: <strong class="text-slate-200">2.4 vCPU</strong></p>
          </div>
          <div class="bg-blue-500/15 p-3 rounded-xl text-blue-400 animate-pulse">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
          </div>
        </div>

        <!-- Próximos -->
        <div class="bg-slate-950 border border-slate-800/80 p-4 rounded-xl flex items-center justify-between shadow-md relative overflow-hidden group">
          <div>
            <p class="text-xs font-bold text-slate-400 tracking-wider uppercase mb-1">Próximos (1h)</p>
            <h3 class="text-2xl font-bold text-amber-400">4</h3>
            <p class="text-[10px] text-slate-400 mt-2">Próximo en <strong class="text-amber-400">12 mins</strong></p>
          </div>
          <div class="bg-amber-500/10 p-3 rounded-xl text-amber-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          </div>
        </div>
      </div>

      <!-- Chart + Server Status -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Chart -->
        <div class="bg-slate-950 border border-slate-800 p-5 rounded-xl lg:col-span-2">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-semibold text-white">Histórico de Ejecuciones (Últimos 7 días)</h4>
            <span class="text-xs bg-slate-900 border border-slate-800 px-2 py-1 rounded-md text-slate-400">Filtro: Todo</span>
          </div>
          <div class="h-64 relative">
            <canvas #dashChart></canvas>
          </div>
        </div>

        <!-- Server Status -->
        <div class="bg-slate-950 border border-slate-800 p-5 rounded-xl">
          <h4 class="font-semibold text-white mb-4">Estado del Servidor PyEngine</h4>
          <div class="flex flex-col gap-4">
            <div>
              <div class="flex justify-between text-xs mb-1">
                <span class="text-slate-400">Uso de Procesador</span>
                <span class="text-slate-200">12% (Hexa-Core)</span>
              </div>
              <div class="w-full bg-slate-900 h-2 rounded-full overflow-hidden">
                <div class="bg-blue-500 h-full rounded-full" style="width:12%"></div>
              </div>
            </div>
            <div>
              <div class="flex justify-between text-xs mb-1">
                <span class="text-slate-400">Uso de RAM</span>
                <span class="text-slate-200">1.4 GB / 8 GB</span>
              </div>
              <div class="w-full bg-slate-900 h-2 rounded-full overflow-hidden">
                <div class="bg-amber-500 h-full rounded-full" style="width:17.5%"></div>
              </div>
            </div>
            <div>
              <div class="flex justify-between text-xs mb-1">
                <span class="text-slate-400">Almacenamiento de logs</span>
                <span class="text-slate-200">45.2 GB / 100 GB</span>
              </div>
              <div class="w-full bg-slate-900 h-2 rounded-full overflow-hidden">
                <div class="bg-emerald-500 h-full rounded-full" style="width:54.8%"></div>
              </div>
            </div>
            <div class="border-t border-slate-800/80 pt-3 text-xs">
              <span class="text-slate-400 font-semibold block mb-2">Colas de Programación</span>
              <div class="grid grid-cols-2 gap-2">
                <div class="bg-slate-900 p-2 rounded border border-slate-800/50">
                  <p class="text-slate-500 text-[10px] uppercase">En Cola</p>
                  <p class="text-lg font-bold text-amber-400">2</p>
                </div>
                <div class="bg-slate-900 p-2 rounded border border-slate-800/50">
                  <p class="text-slate-500 text-[10px] uppercase">Hilos Activos</p>
                  <p class="text-lg font-bold text-blue-400">3 / 8 Max</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Executions Table -->
      <div class="bg-slate-950 border border-slate-800 rounded-xl overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-800 flex items-center justify-between">
          <h4 class="font-semibold text-white">Últimas Ejecuciones del Sistema</h4>
          <button (click)="svc.switchTab('logs')" class="text-blue-500 hover:text-blue-400 text-xs font-semibold flex items-center gap-1">
            Ver todos los logs ›
          </button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-slate-300">
            <thead class="bg-slate-900/60 text-xs font-semibold uppercase text-slate-400 border-b border-slate-800">
              <tr>
                <th class="px-6 py-3.5">Script</th>
                <th class="px-6 py-3.5">Estado</th>
                <th class="px-6 py-3.5">Inicio</th>
                <th class="px-6 py-3.5">Fin</th>
                <th class="px-6 py-3.5">Duración</th>
                <th class="px-6 py-3.5">Usuario</th>
                <th class="px-6 py-3.5 text-right">Acción</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              @for (ex of svc.executions().slice(0, 5); track ex.id) {
                <tr class="hover:bg-slate-900/40 text-xs text-slate-300">
                  <td class="px-6 py-3.5 font-bold text-white">{{ ex.script }}</td>
                  <td class="px-6 py-3.5"><span [class]="statusBadge(ex.status)">{{ ex.status }}</span></td>
                  <td class="px-6 py-3.5 text-slate-500">{{ ex.start }}</td>
                  <td class="px-6 py-3.5 text-slate-500">{{ ex.end }}</td>
                  <td class="px-6 py-3.5 font-semibold">{{ ex.duration }}</td>
                  <td class="px-6 py-3.5">{{ ex.user }}</td>
                  <td class="px-6 py-3.5 text-right">
                    <button (click)="svc.switchTab('logs')" class="text-blue-500 hover:text-blue-400 font-semibold">Ver log</button>
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
export class DashboardComponent implements AfterViewInit {
  @ViewChild('dashChart') chartRef!: ElementRef<HTMLCanvasElement>;
  lastUpdate = 'Justo ahora';
  chart: Chart | null = null;

  constructor(public svc: PyflowService) {}

  get totalScripts() { return this.svc.scripts().length; }
  get activeScripts() { return this.svc.scripts().filter(s => s.status === 'active').length; }
  get runningCount() { return this.svc.executions().filter(e => e.status === 'Ejecutando').length; }

  ngAfterViewInit() { this.initChart(); }

  refresh() {
    this.lastUpdate = new Date().toLocaleTimeString('es-HN', { hour: '2-digit', minute: '2-digit' });
    this.svc.showToast('Dashboard actualizado.', 'info');
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

  initChart() {
    if (!this.chartRef) return;
    const ctx = this.chartRef.nativeElement.getContext('2d');
    if (!ctx) return;
    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Hoy'],
        datasets: [
          { label: 'Exitosas', data: [42, 55, 38, 61, 49, 30, 47], backgroundColor: 'rgba(16,185,129,0.7)', borderRadius: 4 },
          { label: 'Errores', data: [2, 1, 3, 0, 4, 1, 2], backgroundColor: 'rgba(244,63,94,0.7)', borderRadius: 4 }
        ]
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: { legend: { labels: { color: '#94a3b8', font: { size: 11 } } } },
        scales: {
          x: { stacked: true, ticks: { color: '#64748b' }, grid: { color: '#1e293b' } },
          y: { stacked: true, ticks: { color: '#64748b' }, grid: { color: '#1e293b' } }
        }
      }
    });
  }
}
