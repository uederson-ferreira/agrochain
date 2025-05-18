import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { HeaderComponent } from './components/header/header.component';
import { MenuComponent } from './components/menu/menu.component';
import { ResolvemosComponent } from './components/resolvemos/resolvemos.component';
import { ComoFuncionaComponent } from './components/como-funciona/como-funciona.component';
import { BeneficiosComponent } from './components/beneficios/beneficios.component';
import { FooterComponent } from './components/footer/footer.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet,
    HeaderComponent,
    MenuComponent,
    ResolvemosComponent,
    ComoFuncionaComponent,
    BeneficiosComponent,
    FooterComponent
  ],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  title = 'app';

  constructor() {
    // Expor para botão externo do HTML puro
    //(window as any).verificarComZkVerify = this.verificarComZkVerify.bind(this);
      // Escuta o aviso vindo do JS da página de prova
  window.addEventListener('provaPageReady', () => {
      // Agora sim pode registrar o método global
      (window as any).verificarComZkVerify = this.verificarComZkVerify.bind(this);
      console.log("✅ Angular ativou verificação após sinal da prova");
    });
  }

  async verificarComZkVerify() {
    const prova = (window as any).provaGerada;

    if (!prova || !prova.proof || !prova.publicSignals) {
      alert("⚠️ Nenhuma prova encontrada. Gere a prova antes.");
      return;
    }

    try {
      const response = await fetch('https://api.zkverify.io/v1/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          protocol: 'groth16',
          curve: 'bn128',
          proof: prova.proof,
          publicSignals: prova.publicSignals,
          verificationKey: {
            protocol: 'groth16',
            curve: 'bn128',
            nPublic: prova.publicSignals.length
          }
        })
      });

      const result = await response.json();

      if (result.verified) {
        alert('✅ Prova verificada com sucesso via zkVerify API!');
      } else {
        alert('❌ Prova inválida segundo zkVerify API.');
      }

    } catch (err) {
      console.error('Erro ao verificar com zkVerify API:', err);
      alert('🚨 Erro ao verificar com zkVerify API. Veja o console.');
    }
  }
}
