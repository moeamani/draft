import './style.css';
import { App } from './ui/app';

const stage = document.getElementById('stage')!;
const app = new App(stage);
(window as unknown as { draftApp: App }).draftApp = app;
