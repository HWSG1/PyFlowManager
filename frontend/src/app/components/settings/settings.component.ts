import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PyflowService } from '../../services/pyflow.service';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="flex flex-col gap-6">
      <div>
        <h1 class="text-2xl font-bold text-white">Configuración del Sistema</h1>
        <p class="text-sm text-slate-400">
          Administra variables globales utilizadas por los scripts de PyFlow.
        </p>
      </div>

      <div class="grid grid-cols-1 gap-6">
        <div class="bg-slate-950 border border-slate-800 p-5 rounded-xl">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-semibold text-white">
              Variables Globales Compartidas
            </h3>

            <button
              (click)="addVar()"
              class="text-blue-500 hover:text-blue-400 text-xs font-semibold">
              + Agregar Variable
            </button>
          </div>

          <p class="text-xs text-slate-400 mb-4">
            Estas variables se inyectan automáticamente en los scripts cuando son requeridas como parámetro global.
          </p>

          <div class="flex flex-col gap-3">
            @for (v of globalVars; track $index) {
              <div class="grid grid-cols-12 gap-2 items-center">
                <input
                  type="text"
                  [(ngModel)]="v.key"
                  placeholder="VARIABLE"
                  class="col-span-3 bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-blue-500">

                <input
                  [type]="v.isSecret ? 'password' : 'text'"
                  [(ngModel)]="v.value"
                  placeholder="VALOR"
                  class="col-span-3 bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-blue-500">

                <input
                  type="text"
                  [(ngModel)]="v.description"
                  placeholder="Descripción"
                  class="col-span-3 bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-blue-500">

                <label class="col-span-2 flex items-center gap-2 text-xs text-slate-400">
                  <input
                    type="checkbox"
                    [(ngModel)]="v.isSecret">
                  Secreta
                </label>

                <button
                  (click)="removeVar(v, $index)"
                  class="col-span-1 text-rose-500 hover:text-rose-400 text-xs font-semibold text-right">
                  Eliminar
                </button>
              </div>
            }

            @if (!globalVars.length) {
              <div class="text-xs text-slate-500 border border-slate-800 rounded-lg p-4">
                No hay variables globales configuradas.
              </div>
            }
          </div>
        </div>

        <div class="bg-slate-950 border border-slate-800 p-5 rounded-xl">
          <h3 class="font-semibold text-white mb-3">Estado</h3>
          <p class="text-xs text-slate-400">
            Las variables marcadas como secretas se muestran ocultas y no se sobreescriben si mantienen el valor ********.
          </p>
        </div>
      </div>

      <div class="flex justify-end mt-2">
        <button
          (click)="save()"
          class="bg-blue-600 hover:bg-blue-500 text-white font-semibold text-sm px-6 py-2.5 rounded-lg shadow-lg transition-all">
          💾 Guardar Variables
        </button>
      </div>
    </div>
  `
})
export class SettingsComponent implements OnInit {
  globalVars: any[] = [];

  constructor(public svc: PyflowService) {}

  ngOnInit() {
    this.loadVariables();
  }

  loadVariables() {
    this.svc.loadSettings();

    setTimeout(() => {
      this.globalVars = this.svc.envParams().map((x: any) => ({
        id: x.id,
        key: x.key,
        value: x.value,
        isSecret: x.isSecret,
        description: x.description || ''
      }));
    }, 300);
  }

  addVar() {
    this.globalVars.push({
      id: null,
      key: '',
      value: '',
      isSecret: false,
      description: ''
    });
  }

  removeVar(v: any, index: number) {
    if (!v.id) {
      this.globalVars.splice(index, 1);
      return;
    }

    if (!confirm(`¿Deseas eliminar la variable ${v.key}?`)) {
      return;
    }

    this.svc.deleteGlobalVariable(v.id).subscribe({
      next: () => {
        this.svc.showToast('Variable eliminada.', 'info');
        this.globalVars.splice(index, 1);
        this.svc.loadSettings();
      },
      error: err => {
        this.svc.showToast(
          `Error eliminando variable: ${err?.error?.message || err.message}`,
          'error'
        );
      }
    });
  }

  save() {
    const variables = this.globalVars
      .filter(v => String(v.key || '').trim())
      .map(v => ({
        id: v.id,
        var_key: String(v.key || '').trim(),
        var_value: String(v.value ?? ''),
        is_secret: !!v.isSecret,
        description: v.description || null
      }));

    this.svc.saveGlobalVariables(variables).subscribe({
      next: () => {
        this.svc.showToast('Variables globales guardadas correctamente.');
        this.svc.loadSettings();
      },
      error: err => {
        this.svc.showToast(
          `Error guardando variables: ${err?.error?.message || err.message}`,
          'error'
        );
      }
    });
  }
}