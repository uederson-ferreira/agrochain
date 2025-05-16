import { Component, ElementRef, ViewChild, AfterViewInit, OnDestroy } from '@angular/core';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';
import { CommonModule} from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-contato',
  standalone: true,
  imports: [HeaderComponent, FooterComponent, FormsModule, CommonModule],
  templateUrl: './contato.component.html',
  styleUrls: ['./contato.component.css']
})
export class ContatoComponent implements AfterViewInit, OnDestroy {
  nome: string = '';
  email: string = '';
  mensagem: string = '';

  onSubmit() {
    if (this.nome && this.email && this.mensagem) {
      alert('Formulário enviado com sucesso!');
    }
  }

  @ViewChild('canvas') canvasRef!: ElementRef<HTMLCanvasElement>;
  private ctx!: CanvasRenderingContext2D;
  private animationId = 0;
  private width = 0;
  private height = 0;

  private balls: { x: number, y: number, radius: number, dx: number, dy: number, alpha: number }[] = [];

  ngAfterViewInit() {
    const canvas = this.canvasRef.nativeElement;
    this.ctx = canvas.getContext('2d')!;
    this.resizeCanvas();

    // criar bolas
    for (let i = 0; i < 30; i++) {
      this.balls.push({
        x: Math.random() * this.width,
        y: Math.random() * this.height,
        radius: 15 + Math.random() * 10,
        dx: (Math.random() - 0.5) * 0.3,
        dy: (Math.random() - 0.5) * 0.3,
        alpha: 0.15 + Math.random() * 0.3
      });
    }

    this.animate();

    window.addEventListener('resize', () => this.resizeCanvas());
  }

  resizeCanvas() {
    const canvas = this.canvasRef.nativeElement;
    this.width = canvas.clientWidth;
    this.height = canvas.clientHeight;
    canvas.width = this.width * window.devicePixelRatio;
    canvas.height = this.height * window.devicePixelRatio;
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  }

  animate() {
    this.ctx.clearRect(0, 0, this.width, this.height);

    this.balls.forEach(ball => {
      ball.x += ball.dx;
      ball.y += ball.dy;

      if (ball.x < -ball.radius) ball.x = this.width + ball.radius;
      if (ball.x > this.width + ball.radius) ball.x = -ball.radius;
      if (ball.y < -ball.radius) ball.y = this.height + ball.radius;
      if (ball.y > this.height + ball.radius) ball.y = -ball.radius;

      this.ctx.beginPath();
      this.ctx.arc(ball.x, ball.y, ball.radius, 0, Math.PI * 2);
      this.ctx.fillStyle = `rgba(110, 231, 183, ${ball.alpha})`;
      this.ctx.fill();
    });

    this.animationId = requestAnimationFrame(() => this.animate());
  }

  ngOnDestroy() {
    cancelAnimationFrame(this.animationId);
  }
}
