import { ComponentFixture, TestBed } from '@angular/core/testing';

import { DepoimentosComponent } from './depoimentos.component';

describe('DepoimentosComponent', () => {
  let component: DepoimentosComponent;
  let fixture: ComponentFixture<DepoimentosComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DepoimentosComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(DepoimentosComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
