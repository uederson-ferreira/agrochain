import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ResolvemosComponent } from './resolvemos.component';

describe('ResolvemosComponent', () => {
  let component: ResolvemosComponent;
  let fixture: ComponentFixture<ResolvemosComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ResolvemosComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ResolvemosComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
