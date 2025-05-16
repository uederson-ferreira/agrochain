import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';

@Component({
  selector: 'app-depoimentos',
  standalone: true,
  imports: [HeaderComponent, FooterComponent,CommonModule],
  templateUrl: './depoimentos.component.html',
  styleUrl: './depoimentos.component.css'
})
export class DepoimentosComponent {
    depoimentos = [
    {
      nome: 'Maria Silva',
      cargo: 'Produtora Rural',
      mensagem: 'A plataforma agilizou todo o processo da fazenda. Foi um salto de eficiência!',
      avatar: 'https://randomuser.me/api/portraits/women/44.jpg',
      estrelas: 5
    },
    {
      nome: 'João Pereira',
      cargo: 'Engenheiro Agrônomo',
      mensagem: 'Com essa solução, conseguimos aumentar a produtividade com menor desperdício.',
      avatar: 'https://randomuser.me/api/portraits/men/32.jpg',
      estrelas: 4
    },
    {
      nome: 'Ana Souza',
      cargo: 'Coordenadora de Logística',
      mensagem: 'O sistema é intuitivo e confiável. Facilitou muito nosso controle de estoque.',
      avatar: 'https://randomuser.me/api/portraits/women/68.jpg',
      estrelas: 5
    },
    {
      nome: 'Carlos Lima',
      cargo: 'Técnico Agrícola',
      mensagem: 'Antes tínhamos muito retrabalho. Agora temos previsibilidade e menos erros.',
      avatar: 'https://randomuser.me/api/portraits/men/54.jpg',
      estrelas: 5
    },
    {
      nome: 'Fernanda Rocha',
      cargo: 'Gestora de Produção',
      mensagem: 'O suporte técnico é excelente. Resolveram tudo rapidamente!',
      avatar: 'https://randomuser.me/api/portraits/women/85.jpg',
      estrelas: 4
    },
    {
      nome: 'Eduardo Menezes',
      cargo: 'Administrador de Fazenda',
      mensagem: 'Com a integração da plataforma, conseguimos economizar tempo e recursos. É um divisor de águas no campo.',
      avatar: 'https://randomuser.me/api/portraits/men/75.jpg',
      estrelas: 5
    }
  ];
}

