# Concepto de videojuego — Investigación, viajes en el tiempo y crímenes históricos

> **Estado de implementación:** el vertical slice del Caso 001 ya está implementado en Godot 4.7.2 como **MERIDIAN — Archivo temporal**, en 3D y primera persona. Incluye el ciclo completo desde la investigación en el presente hasta la captura no letal, la reparación y el regreso. Consulta el [README](../README.md) para ejecutarlo, ver los controles, las licencias y el alcance real. Este documento conserva la visión de campaña; las otras épocas y los sistemas de largo plazo no están implementados.

## 1. Concepto general

La idea es desarrollar un videojuego de investigación y aventura basado en **viajes en el tiempo**, donde el jugador pertenece a una organización especializada en investigar delitos relacionados con alteraciones temporales.

El concepto combina elementos de:

- Investigación detectivesca.
- Viajes en el tiempo.
- Historia.
- Reconstrucción de acontecimientos.
- Recolección de evidencias.
- Interrogatorios y testimonios.
- Persecuciones.
- Sigilo.
- Acción.
- Líneas temporales alternativas.
- Resolución de casos.

La propuesta toma como referencia conceptual el espíritu de juegos como **Carmen Sandiego**, especialmente su componente de investigación, búsqueda de pistas, identificación de sospechosos y viajes por diferentes lugares, pero incorpora una identidad propia basada en **crímenes temporales y alteración de la historia**.

---

# 2. Premisa narrativa

En el futuro existe una organización especializada en combatir delitos tecnológicos y temporales.

Durante la captura de un criminal especializado en ciberdelitos, los agentes descubren un dispositivo desconocido.

Inicialmente parece un artefacto tecnológico experimental.

Sin embargo, el análisis revela algo extraordinario:

> El dispositivo permite viajar a diferentes momentos de la historia.

La investigación descubre además que no se trata de un caso aislado.

Existe una red de criminales que está utilizando dispositivos de viaje temporal para regresar a diferentes momentos históricos y modificar acontecimientos con el objetivo de obtener beneficios en el presente o en el futuro.

El problema es que cada modificación puede producir una **divergencia temporal**.

La organización debe localizar a los responsables, reconstruir sus movimientos, identificar qué acontecimiento quieren modificar y detenerlos antes de que alteren la historia de forma irreversible.

---

# 3. Objetivo del jugador

El jugador forma parte de una unidad especializada en delitos temporales.

Su objetivo principal es:

> **Investigar, localizar e identificar a criminales que utilizan tecnología temporal para alterar acontecimientos históricos y capturarlos antes de que produzcan una divergencia irreversible.**

El jugador no recibe directamente la ubicación del criminal.

Debe construir el caso mediante evidencias.

---

# 4. Estructura principal del gameplay

El ciclo principal del juego puede estructurarse de la siguiente manera:

```text
CENTRO DE CONTROL
       |
       v
ANALIZAR EVIDENCIAS
       |
       v
RECONSTRUIR EL CASO
       |
       v
IDENTIFICAR ÉPOCA / UBICACIÓN
       |
       v
VIAJE TEMPORAL
       |
       v
INVESTIGACIÓN HISTÓRICA
       |
       v
RECOLECCIÓN DE EVIDENCIAS
       |
       v
INTERROGATORIOS
       |
       v
IDENTIFICACIÓN DEL SOSPECHOSO
       |
       v
ORDEN DE CAPTURA
       |
       v
PERSECUCIÓN / CAPTURA
       |
       v
REGRESO AL PRESENTE
       |
       v
ANÁLISIS DE LA LÍNEA TEMPORAL
       |
       v
SIGUIENTE CASO
```

---

# 5. Nivel 1 — Investigación en el presente

El jugador trabaja inicialmente desde el centro de operaciones.

Puede disponer de:

- Archivos históricos.
- Bases de datos.
- Fotografías.
- Documentos.
- Objetos recuperados.
- Comunicaciones interceptadas.
- Análisis forense.
- Registros de viajes temporales.
- Mapas.
- Información histórica.
- Testimonios.
- Registros de personas.
- Evidencias digitales.

El jugador debe combinar estas fuentes para reconstruir el caso.

---

# 6. Evidencias

La investigación debería contar con un sistema de evidencias.

Cada evidencia puede tener un nivel de confiabilidad.

Ejemplo:

```text
EVIDENCIA

Testimonio de comerciante
Estado: Confirmado

Objeto encontrado
Estado: Confirmado

Registro temporal
Estado: Probable

Descripción física del sospechoso
Estado: Probable

Motivo
Estado: Incompleto
```

También pueden existir evidencias contradictorias.

Esto obliga al jugador a analizar la información en lugar de simplemente seguir un marcador en el mapa.

---

# 7. Identificación del sospechoso

El jugador debe construir un caso antes de poder emitir una orden de captura.

Ejemplo:

```text
SOSPECHOSO
-------------------------
Marcus Vale

Identidad       82%
Ubicación       94%
Motivo          71%
Cómplices       43%

EVIDENCIAS
-------------------------
✓ Testimonio
✓ Objeto recuperado
✓ Registro temporal
✓ Comunicación interceptada
✓ Descripción física

ORDEN DE CAPTURA
-------------------------
Estado: AUTORIZABLE
```

La identificación debería depender de la calidad y cantidad de las evidencias.

---

# 8. Viaje temporal

Una vez que el equipo determina aproximadamente dónde y cuándo se encuentra el criminal, el jugador utiliza el dispositivo temporal.

Ejemplo:

```text
DESTINO

Año: 2560 a.C.
Ubicación: Egipto
Zona: Meseta de Guiza

Anomalía temporal: 72%
Riesgo de divergencia: Alto
```

El jugador es transportado a la época correspondiente.

---

# 9. Representación histórica

Uno de los elementos fundamentales del juego debería ser la representación de cada época.

Cuando el jugador viaja al pasado, el escenario debe intentar representar el período histórico de forma coherente.

Elementos posibles:

- Arquitectura.
- Vestimenta.
- Idiomas.
- Costumbres.
- Herramientas.
- Armas.
- Vehículos.
- Organización social.
- Economía.
- Religión.
- Geografía.
- Clima.
- Tecnología disponible.
- Personajes históricos.
- Alimentación.
- Transporte.

La intención es que cada época se sienta diferente.

---

# 10. Investigación dentro de la época

Una vez que llega a la época histórica, comienza una segunda etapa de investigación.

El jugador puede:

- Hablar con habitantes.
- Interrogar testigos.
- Buscar objetos.
- Seguir rastros.
- Investigar lugares.
- Comparar testimonios.
- Detectar inconsistencias.
- Reconstruir recorridos.
- Identificar aliados del criminal.
- Descubrir el objetivo del criminal.

El jugador no debería saber inmediatamente dónde está el sospechoso.

---

# 11. Ejemplo de misión — Egipto

## Caso 001 — La pirámide

Se detecta una anomalía temporal alrededor del año 2560 a.C.

La organización sospecha que alguien está intentando alterar acontecimientos relacionados con la construcción de la Gran Pirámide.

### Investigación inicial

El jugador encuentra:

1. Un objeto moderno en una excavación.
2. Una aleación que no debería existir en esa época.
3. Un testigo que afirma haber visto a un extranjero.
4. Otro testigo recuerda una característica física.
5. Un comerciante recuerda haber vendido alimentos a esa persona.
6. Se reconstruye la ruta del sospechoso.
7. Se descubre que contactó con determinado constructor.
8. Se determina qué está buscando.
9. Se identifica al criminal.

Entonces se genera una:

> **ORDEN DE CAPTURA TEMPORAL**

---

# 12. Persecuciones

Una vez identificado el sospechoso, la misión puede pasar a una fase de persecución.

La persecución debe respetar las características de la época.

Por ejemplo:

## Egipto

- Corriendo.
- Caballos.
- Carros.
- Embarcaciones.
- Persecución por mercados.
- Escalada.
- Recorridos por construcciones.

## Roma

- Caballos.
- Carros.
- Calles urbanas.
- Puertos.
- Persecuciones a pie.

## Edad Media

- Caballos.
- Carretas.
- Barcos.
- Fortificaciones.

## Siglo XIX

- Carruajes.
- Trenes.
- Barcos.
- Vehículos de la época.

## Siglo XX

- Automóviles.
- Motocicletas.
- Trenes.
- Aviones.

Esto permite que cada período tenga mecánicas de persecución propias.

---

# 13. Combate y armas

El juego puede incorporar armas, pero deberían complementar la investigación y no convertirse en el elemento principal.

Las armas podrían depender de la época:

- Espadas.
- Arcos.
- Lanzas.
- Mosquetes.
- Pistolas.
- Revólveres.
- Rifles.
- Armas modernas.

Una mecánica interesante sería limitar el uso de armas para evitar alteraciones innecesarias.

Por ejemplo:

> El jugador puede defenderse, pero matar a una persona que originalmente debía sobrevivir puede producir una divergencia temporal.

Esto genera consecuencias por las acciones del jugador.

---

# 14. Sistema de divergencia temporal

La historia original puede representarse como una línea temporal.

```text
HISTORIA ORIGINAL

Egipto
   |
Grecia
   |
Roma
   |
Edad Media
   |
Revolución Industrial
   |
Siglo XX
   |
Actualidad
```

Si un criminal modifica un acontecimiento:

```text
                 Historia original
                       |
Egipto ----------------+
                       |
                       +---- Historia alterada
```

El juego puede medir el nivel de divergencia.

Ejemplo:

```text
DIVERGENCIA TEMPORAL

██████████░░░░░░░░  52%

Estado: PELIGROSO
```

Cuanto mayor sea la divergencia, mayores pueden ser las consecuencias en el presente.

---

# 15. Líneas temporales alternativas

Una característica central puede ser la existencia de diferentes líneas temporales.

Ejemplo:

```text
                         ┌── Línea Alpha
                         |
Historia original -------┼── Línea Beta
                         |
                         └── Línea Gamma
```

Algunas misiones podrían desarrollarse en líneas temporales que ya fueron alteradas.

Esto permite que el jugador descubra que determinados acontecimientos del mundo actual no coinciden con los registros originales.

---

# 16. Tipos de criminales

Los criminales pueden tener objetivos diferentes.

## Criminal orientado al poder

Busca modificar una guerra para favorecer a un determinado imperio.

## Criminal orientado al dinero

Introduce tecnología o conocimientos adelantados para obtener una ventaja económica.

## Criminal manipulador

Modifica acontecimientos para cambiar el desarrollo político de una sociedad.

## Criminal motivado por venganza

Busca impedir que determinado acontecimiento histórico ocurra.

## Criminal que busca inmortalidad

Pretende convertirse en una figura histórica.

## Criminal tecnológico

Introduce tecnología avanzada en una época donde no debería existir.

## Coleccionista

Roba objetos históricos antes de que sean creados o utilizados.

---

# 17. La organización criminal

Puede existir una organización detrás de varios casos.

Al principio, los criminales parecen actuar de forma independiente.

Con el avance de la historia:

```text
Caso 01
   |
Caso 02
   |
Caso 03
   |
Caso 04
   |
   v
Descubrimiento de conexión
   |
   v
Organización criminal
   |
   v
Origen de la tecnología temporal
```

El jugador descubre progresivamente quién está detrás de los acontecimientos.

---

# 18. Posible giro argumental

Una posibilidad narrativa interesante:

El dispositivo temporal no fue creado originalmente por los criminales.

Fue desarrollado por la propia organización del jugador.

Alguien robó la tecnología.

Esto puede generar una segunda capa narrativa:

> La organización que intenta reparar la historia también es responsable indirectamente de haber creado la tecnología que permite destruirla.

Este elemento puede utilizarse como giro de la campaña principal.

---

# 19. Ejemplos de épocas

El juego podría visitar diferentes períodos históricos.

Algunos ejemplos:

- Egipto antiguo.
- Mesopotamia.
- Grecia antigua.
- Imperio Romano.
- Edad Media.
- Renacimiento.
- Conquista y colonización de América.
- Revolución Francesa.
- Revolución Industrial.
- Guerra Civil estadounidense.
- Primera Guerra Mundial.
- Segunda Guerra Mundial.
- Guerra Fría.
- Décadas recientes.

Cada época debería seleccionarse no solamente por ser conocida, sino porque ofrece posibilidades jugables.

---

# 20. Tratamiento de acontecimientos históricos sensibles

Al trabajar con acontecimientos como esclavitud, colonización, guerras y genocidios, el juego debería evitar convertir el sufrimiento histórico en un simple escenario de entretenimiento.

Estos períodos pueden utilizarse como contexto narrativo e investigativo, pero deberían tratarse con documentación histórica y cuidado.

La ficción puede introducir criminales y alteraciones temporales sin afirmar que los acontecimientos históricos reales ocurrieron de manera diferente.

---

# 21. Sistema de conocimiento histórico

El jugador puede tener una base de conocimiento que se actualiza durante la campaña.

Ejemplo:

```text
HISTORIA CONOCIDA

2560 a.C.
Construcción de la Gran Pirámide

480 a.C.
Guerras Médicas

44 a.C.
Asesinato de Julio César

1492
Llegada europea a América

1789
Revolución Francesa

1914
Primera Guerra Mundial

1939
Segunda Guerra Mundial

2026
ACTUALIDAD
```

Cuando ocurre una modificación:

```text
⚠ DIVERGENCIA DETECTADA

Historia original
████████████████████

Historia actual
██████████░░░░░░░░

Divergencia: 37%
```

---

# 22. Estructura de una misión completa

Una misión podría seguir esta estructura:

### Fase 1 — Briefing

El jugador recibe el caso.

### Fase 2 — Análisis

Se estudian evidencias iniciales.

### Fase 3 — Reconstrucción

Se determina:

- época;
- ubicación;
- posible objetivo;
- posibles sospechosos.

### Fase 4 — Viaje

El jugador viaja a la época correspondiente.

### Fase 5 — Investigación

Se recolectan evidencias y testimonios.

### Fase 6 — Reconstrucción

Se reconstruyen los movimientos del criminal.

### Fase 7 — Identificación

Se determina quién es el sospechoso.

### Fase 8 — Orden de captura

La organización autoriza la captura.

### Fase 9 — Persecución

El criminal intenta escapar.

### Fase 10 — Captura

El jugador debe detenerlo.

### Fase 11 — Regreso

Se vuelve al presente.

### Fase 12 — Consecuencias

Se verifica que la línea temporal continúe estable.

---

# 23. Diferencia respecto de Carmen Sandiego

La inspiración conceptual puede ser:

**Carmen Sandiego**

- Investigación.
- Pistas.
- Testimonios.
- Viajes.
- Identificación de criminales.
- Captura.

Pero el nuevo proyecto agregaría:

- Viajes en el tiempo.
- Historia real.
- Líneas temporales alternativas.
- Divergencias temporales.
- Investigación forense.
- Evidencias digitales.
- Persecuciones históricas.
- Combate.
- Consecuencias de las acciones del jugador.
- Trama global relacionada con una organización criminal.

Por lo tanto, el objetivo no debería ser crear "otro Carmen Sandiego", sino desarrollar una identidad propia:

> **Un thriller detectivesco de viajes temporales donde el jugador debe investigar crímenes históricos y detener a quienes intentan reescribir la historia.**

---

# 24. Diseño inicial recomendado

No conviene comenzar desarrollando un mundo enorme.

La propuesta debería comenzar con un **Vertical Slice**.

## Vertical Slice — Caso 001: Egipto

Un único escenario histórico.

Debe permitir probar:

- Centro de operaciones.
- Sistema de evidencias.
- Investigación.
- Base histórica.
- Viaje temporal.
- Escenario histórico.
- NPCs.
- Interrogatorios.
- Recolección de pistas.
- Identificación del sospechoso.
- Orden de captura.
- Persecución.
- Captura.
- Regreso al presente.
- Sistema básico de divergencia temporal.

Si este caso resulta divertido, se puede utilizar como base para ampliar el juego.

---

# 25. Escala del proyecto

No sería recomendable intentar inicialmente:

- Mundo abierto.
- Decenas de épocas.
- Vehículos complejos.
- Combate avanzado.
- Multijugador.
- Cientos de NPCs.
- Simulación histórica completa.

Eso convertiría el proyecto rápidamente en un desarrollo de enorme escala.

Una primera versión podría utilizar:

### Opción A — 2D

Pixel art o ilustración 2D.

Ventajas:

- Menor coste de producción.
- Desarrollo más rápido.
- Permite concentrarse en la investigación.
- Facilita crear diferentes épocas.

### Opción B — 2.5D

Personajes 2D sobre escenarios con profundidad.

Permite una presentación más moderna sin el coste completo de un juego 3D.

### Opción C — 3D

Una evolución posterior si el concepto demuestra ser divertido y viable.

---

# 26. Identidad del juego

El elemento diferenciador debería ser:

> **Investigar el pasado para proteger el futuro.**

El jugador no simplemente viaja por la historia.

Tiene que:

1. descubrir qué ocurrió;
2. determinar qué no debería estar ocurriendo;
3. reconstruir quién lo provocó;
4. demostrarlo mediante evidencias;
5. localizar al criminal;
6. capturarlo;
7. reparar la línea temporal.

---

# 27. Potencial para una campaña

La campaña podría comenzar con casos independientes.

Después, los casos comienzan a conectarse.

```text
CASOS INDEPENDIENTES
        ↓
ANOMALÍAS
        ↓
CRIMINALES RELACIONADOS
        ↓
ORGANIZACIÓN
        ↓
TECNOLOGÍA TEMPORAL
        ↓
ORIGEN DEL DISPOSITIVO
        ↓
CONSPIRACIÓN
        ↓
FINAL DE CAMPAÑA
```

Esto permitiría que el jugador aprenda progresivamente las mecánicas mientras descubre la historia principal.

---

# 28. Resumen del concepto

### Género

Aventura detectivesca + investigación + viajes temporales + acción.

### Perspectiva

Por definir: 2D, 2.5D o 3D.

### Jugador

Agente especializado en delitos temporales.

### Objetivo

Investigar y capturar criminales que intentan modificar acontecimientos históricos.

### Mecánica principal

```text
PISTAS
→ INVESTIGACIÓN
→ DEDUCCIÓN
→ VIAJE TEMPORAL
→ INVESTIGACIÓN HISTÓRICA
→ EVIDENCIAS
→ IDENTIFICACIÓN
→ ORDEN DE CAPTURA
→ PERSECUCIÓN
→ CAPTURA
→ REPARACIÓN TEMPORAL
```

### Gran conflicto

Una organización criminal utiliza tecnología de viajes temporales para alterar acontecimientos históricos y obtener beneficios.

### Gran misterio

¿Quién creó realmente la tecnología temporal y por qué?

---

# 29. Visión a largo plazo

Si el concepto funciona, el juego podría evolucionar desde un primer caso pequeño hasta una campaña completa con:

- Múltiples épocas.
- Diferentes líneas temporales.
- Criminales recurrentes.
- Organizaciones rivales.
- Personajes históricos.
- Vehículos históricos.
- Sistemas de combate.
- Sigilo.
- Investigaciones complejas.
- Casos secundarios.
- Decisiones del jugador.
- Consecuencias temporales.
- Diferentes finales.
- Línea temporal dinámica.
- Base de datos histórica.
- Sistema de reputación dentro de la organización.

La característica central debería mantenerse siempre:

> **El jugador no sabe la respuesta. Tiene que descubrirla.**

---

# 30. Próximo paso recomendado

Antes de programar, conviene convertir esta idea en un **Game Design Document (GDD)** más formal.

El siguiente documento debería definir:

1. Nombre provisional del juego.
2. Pitch de una frase.
3. Género.
4. Público objetivo.
5. Plataforma.
6. Estilo visual.
7. Cámara.
8. Core gameplay loop.
9. Mecánicas principales.
10. Sistema de investigación.
11. Sistema de evidencias.
12. Sistema de interrogatorios.
13. Sistema de viajes temporales.
14. Sistema de líneas temporales.
15. Sistema de divergencias.
16. Persecuciones.
17. Combate.
18. NPCs.
19. Criminales.
20. Organización del jugador.
21. Historia principal.
22. Primer caso.
23. Progresión.
24. Arquitectura técnica.
25. Alcance del MVP.
26. Roadmap de desarrollo.

El objetivo debería ser diseñar primero un **prototipo jugable de un único caso histórico**, validar que el ciclo de investigación sea divertido y recién después ampliar el universo.
