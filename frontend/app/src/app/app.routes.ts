import { Routes } from '@angular/router';
import { ContatoComponent } from './components/contato/contato.component';
import { HomeComponent } from './components/home/home.component';
import { DepoimentosComponent } from './components/depoimentos/depoimentos.component';


export const routes: Routes = [
  { path: '', component: HomeComponent },
  { path: 'contato', component: ContatoComponent },
  { path: 'depoimentos', component: DepoimentosComponent},
  { path: '**', redirectTo: '' } 
];
