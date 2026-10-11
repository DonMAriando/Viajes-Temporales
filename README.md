# MERIDIAN - Archivo temporal

**Investigar el pasado para proteger el futuro.**

Aventura detectivesca 3D en primera persona, implementada en **Godot 4.7.2** a partir del [concepto original](docs/concepto_juego_viajes_temporales.md). El presente narrativo es 2089; el primer destino es Guiza, durante la IV dinastia, aproximadamente en 2560 a. C.

## Alcance implementado

El **Caso 001: La piramide** se puede jugar de principio a fin: briefing, investigacion forense en el centro de operaciones, deduccion del destino, viaje, testimonios, contraste de pruebas, identificacion, orden de captura, persecucion a pie, captura no letal, neutralizacion del sabotaje, reparacion del ancla, regreso y evaluacion del expediente.

Incluye diez evidencias, cuatro deducciones, tres sospechosos, cuatro testigos, trabajadores con recorridos, mapa consultable, archivo historico, cronologia, guardado, ajustes y consecuencias distintas para las lineas Alpha y Beta. Las interfaces pausan el tiempo de campo; repetir respuestas no permite acumular confianza ni puntuacion.

La direccion artistica utiliza modelos CC0, anatomia humana articulada, materiales PBR, iluminacion Forward+, ropa de lino ajustada al contorno corporal, arena, piedra, ceramica y madera. El cuerpo se conserva bajo la ropa y el borde doblado del cinturon cierra la union con la cintura. La caminata y la carrera alternan apoyo y balanceo, articulan rodillas y tobillos y compensan el movimiento de brazos y torso. Las animaciones se mezclan y ajustan a la zancada exportada, la estatura y la velocidad real de desplazamiento. Es un **vertical slice jugable**, no una campana AAA terminada ni una garantia de fotorrealismo absoluto. Las otras epocas, vehiculos, combate armado, sigilo avanzado y doblaje no estan implementados.

## Jugar en Windows

Desde la raiz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1
```

El lanzador localiza un motor instalado o descarga Godot 4.7.2 oficial en `.tools`, verifica su SHA512 e importa los recursos antes de arrancar. La primera importacion puede tardar. Los modelos y texturas finales estan incluidos: **no hace falta Node.js, Python ni Blender para jugar**. Se necesita conexion a Internet solamente si hay que obtener el motor.

El renderizador Forward+ requiere una GPU y controladores compatibles con Vulkan. El menu de ajustes permite reducir calidad, desactivar el balanceo, cambiar sensibilidad, invertir el raton, ajustar el campo visual, activar pantalla completa y regular los volumenes.

Para usar otra instalacion exacta de Godot 4.7.2:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -GodotPath 'C:\Godot\Godot_v4.7.2-stable_win64.exe'
```

## Controles

| Entrada | Accion |
| --- | --- |
| WASD / flechas | Moverse |
| Raton | Mirar |
| Shift | Correr, con resistencia |
| Ctrl | Agacharse, con comprobacion fisica del techo |
| Espacio | Saltar |
| E | Hablar, examinar o interactuar |
| Mantener E | Captura no letal, con orden, proximidad y linea de vision |
| Tab / J | Expediente: evidencias, deducciones, sospechosos, mapa, archivo y cronologia |
| Q | Escaner de corto alcance; no revela pruebas a traves de paredes |
| F | Linterna |
| Esc | Cerrar la interfaz actual / pausar |
| F5 | Guardado rapido |

Para empezar, acepta el briefing y examina las estaciones del centro. **Recoger una evidencia no equivale a analizarla**: utiliza su ficha forense y el expediente para fundamentar las deducciones. La orden exige respaldo suficiente de identidad, ubicacion y motivo. El regreso solo se habilita tras detener al responsable, neutralizar el resonador y reparar el ancla.

## Guardado

El juego guarda al alcanzar hitos, cada 45 segundos durante el juego, desde pausa y al salir. Utiliza `user://case_001.json`, una copia `.bak` y escritura temporal; rechaza archivos incompatibles o invalidos y permite recuperar la copia anterior.

En Windows, la carpeta habitual es:

```text
%APPDATA%\Godot\app_userdata\MERIDIAN - Archivo temporal\
```

Los ajustes se almacenan en `preferences.cfg`. Iniciar un caso nuevo reemplaza el progreso despues de confirmarlo. Las herramientas de comprobacion y capturas utilizan rutas separadas en `user://verification` y no sobrescriben la partida normal.

## Desarrollo

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Mode Editor
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Mode Import
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Mode Test
```

El modo Test arranca una escena Godot normal con los autoloads del juego. Comprueba reglas de investigacion, umbrales probatorios, rumores, consecuencias, persistencia y corrupcion, controles sobre geometria real, colision de la puerta principal, sincronizacion de las zancadas, navegacion hasta el embarcadero, captura y cierre completo mediante las interfaces. Tambien detecta errores de scripts aunque el motor devuelva codigo cero.

| Ruta | Responsabilidad |
| --- | --- |
| `data\cases\case_001.json` | Evidencias, conversaciones, sospechosos, deducciones y referencias historicas |
| `scripts\core` | Estado del caso, divergencia, persistencia y preferencias |
| `scripts\world` | Escenarios, recursos PBR, interacciones y NPCs con navegacion |
| `scripts\player` | Movimiento, camara, escalones y deteccion de interacciones |
| `scripts\ui` | Menu, HUD, expediente, dialogos, mapa y ajustes |
| `scripts\audio` | Ambientes, pasos y efectos originales |
| `shaders` | Agua, tejido, vegetacion y efectos temporales |
| `tools` | Motor portable y pipeline reproducible de recursos |
| `tests` | Integracion del caso y capturas de GPU |

Los escenarios se construyen desde `TemporalWorld`; no son escenas de decorado vacias que haya que completar manualmente en el editor. El estado persistente vive en `CaseState`, no en los nodos del mundo. La malla de navegacion respeta obstaculos y el acceso occidental al embarcadero elevado.

El centro tiene una puerta principal de doble hoja, con marco, tiradores, lector de acceso y senalizacion de seguridad. Permanece cerrada durante este caso y no habilita una zona exterior. Utiliza reflejos de pantalla en calidad equilibrada y alta. Se evitan los `ReflectionProbe` dinamicos: en Godot 4.7.2 su destruccion deja advertencias de siete texturas RID incluso en una escena minima sin assets del juego.

## Recursos y licencias

| Procedencia | Uso | Licencia |
| --- | --- | --- |
| [Poly Haven](https://polyhaven.com) | Siete familias PBR y siete modelos de ceramica, cestas, rocas y cajas | CC0 1.0 |
| [MakeHuman Community](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) | Anatomia, rig, pesos, ojos y piel de los personajes | CC0 1.0 para assets |
| [Manrope](https://github.com/googlefonts/manrope) y [Cinzel](https://github.com/NDISCOVER/Cinzel) | Tipografia | SIL Open Font License 1.1 |

`assets\manifest.json` registra los origenes, las licencias, los tamanos y el SHA256 de los archivos descargados. Los textos de licencia de MakeHuman y las fuentes estan en `assets\licenses`. No se ha incorporado codigo de la aplicacion MakeHuman.

La geometria de ropa, sandalias, cicatriz, escenarios, animaciones, efectos y audio se genera con herramientas originales del proyecto. `linen_undyed.png` es una variante sin tenir derivada del lino CC0 de Poly Haven, conservando su trama. Los GLB finales incluyen un esqueleto articulado y las animaciones `idle`, `walk`, `run` y `captured`.

Solo para regenerar recursos se requiere **Node.js 22 o posterior**:

```powershell
node .\tools\fetch_assets.mjs
& '.\tools\setup_godot.ps1'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path (Get-Location).Path --script 'res://tools/prepare_textures.gd'
node .\tools\build_characters.mjs
node --test .\tests\character_assets.test.mjs
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Mode Import
```

La descarga verifica los hashes fijados y los tamanos; las fuentes intermedias quedan en `.asset_sources`, ignorada por Git. La importacion del motor queda en `.godot`, tambien ignorada. Mantener `assets`, los archivos `.import` y los `.uid` del proyecto al distribuir el codigo.

## Historia y ficcion

Guiza es una reconstruccion artistica, no una reconstruccion arqueologica exacta. Las referencias del archivo distinguen hechos documentados, dataciones aproximadas e interpretaciones. La agencia MERIDIAN, los personajes, Asterion, el sabotaje y los viajes temporales son ficcion.

En el Reino Antiguo no se utilizan caballos ni carros para esta persecucion: la huida es a pie hacia un embarcadero. No se presenta a toda la poblacion trabajadora como esclava ni se atribuye el desarrollo historico real a los criminales ficticios.
