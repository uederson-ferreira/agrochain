import { Component } from '@angular/core';
import { HeaderComponent } from '../../components/header/header.component';
import { MenuComponent } from '../../components/menu/menu.component';
import { ResolvemosComponent } from '../../components/resolvemos/resolvemos.component';
import { ComoFuncionaComponent } from '../../components/como-funciona/como-funciona.component';
import { BeneficiosComponent } from '../../components/beneficios/beneficios.component';
import { FooterComponent } from '../../components/footer/footer.component';

@Component({
  selector: 'app-home',
  standalone: true,
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css'],
  imports: [
    HeaderComponent,
    MenuComponent,
    ResolvemosComponent,
    ComoFuncionaComponent,
    BeneficiosComponent,
    FooterComponent
  ]
})
export class HomeComponent {}
