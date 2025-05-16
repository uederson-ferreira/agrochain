import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { HeaderComponent } from "./components/header/header.component";
import { MenuComponent } from "./components/menu/menu.component";
import { ResolvemosComponent } from "./components/resolvemos/resolvemos.component";
import { ComoFuncionaComponent } from "./components/como-funciona/como-funciona.component";
import { BeneficiosComponent } from "./components/beneficios/beneficios.component";
import { FooterComponent } from "./components/footer/footer.component";

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  title = 'app';
}
