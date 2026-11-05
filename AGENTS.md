# AGENTS.md

Guía de trabajo para sesiones de OpenCode en este repositorio. Contenido en español: mantén ese idioma en los ficheros del paquete.

## Qué es este repo

No es una aplicación: es un **bundle de configuración** para OpenCode V2 (orquestador + 5 subagentes). No hay builds, tests, CI ni toolchain.

- `agents/` — 6 ficheros `.md` con frontmatter (`description`, `mode`, `model`, `steps`, `permissions`): `orchestrator` (`mode: primary`, sin `model` ni `steps`: hereda el modelo de la config) + `code`, `debug`, `research`, `review`, `architect` (todos `mode: subagent` con `steps` 60 para `code`/`debug` y 30 para los otros tres; `research`/`review`/`architect` deniegan `edit` y `shell` salvo allowlist de solo lectura — `git status/diff/log/branch`, `ls` — para que no puedan escribir por la vía `shell`).
- `proyecto/.opencode/` — variante que se copia tal cual a la raíz de un repo de equipo: `opencode.json` + copia de los agentes.
- `opencode-global.example.json` — plantilla para instalación en config global.
- `install.sh` — instalación en `~/.config/opencode/`.

## Sincronización obligatoria (lo más fácil de olvidar)

Existen **dos copias** de cada agente y de la configuración; al editar uno hay que aplicar el cambio importándolo de su origen:

- `agents/*.md` ↔ `proyecto/.opencode/agents/*.md` (idénticos hoy; verificar con `diff -rq agents proyecto/.opencode/agents`).
- `opencode-global.example.json` ↔ `proyecto/.opencode/opencode.json` (idénticos hoy).
- `~/.config/opencode/agents/*.md` es una **tercera copia** (lo que realmente se ejecuta cuando abres OpenCode en cualquier sitio). Si editas ahí directamente o instalas con `install.sh`, arrastra ese cambio a `agents/` y a `proyecto/.opencode/agents/` antes de terminar: es exactamente así como quedaron fuera del repo las secciones de contexto de directorio, RTK y reintentos del orquestador.

Tras cualquier cambio, ejecuta esas comparaciones y aplica la edición en ambas copias antes de terminar. Además, el enrutado de modelos es dinámico (regla MODEL ROUTER en `agents/orchestrator.md`): los 5 subagentes NO fijan `model` en su frontmatter — el orquestador pasa el modelo en cada delegación (con fallback a `opencode/beam-free` si el tier gratuito se agota) —; el campo `model` de ambos `opencode.json` solo fija el modelo del orquestador. Los IDs de los tiers gratuitos cambian a menudo: verifica el catálogo actual (`tools.opencode.models` filtrando coste 0) antes de editar la matriz.

## Config y permisos

- La config es **OpenCode V2**: `permissions` es una lista `{action, resource, effect}`. No uses claves deprecadas de V1.
- `default_agent: orchestrator`; `edit` en `allow` y `shell` en `ask` con allowlist de solo lectura (`git status/diff/log/branch`, `ls`); ambos heredan el cwd del proyecto invocado; `external_directory`, `webfetch` y `subagent` en `ask`.
- La delegación a subagentes es semiautomática: `subagent` también está en `ask` (reglas completas en `agents/orchestrator.md`).
- OpenCode recarga la config automáticamente al guardar; no hace falta reiniciar.

## Probar install.sh sin tocar tu config real

```sh
OPENCODE_CONFIG_DIR=/tmp/test-opencode ./install.sh
```

Nunca lo ejecutes contra un `~/.config/opencode` de desarrollo sin querer: el instalador sobrescribe agentes (hace backup, pero igualmente). Su comportamiento de merge respeta `default_agent` y el modelo existentes del usuario, coloca el bloque de permisos del paquete **delante** de los suyos (gana la última regla que coincide: sus reglas siguen aplicándose y el `ask` del paquete no se pierde) y deduplica.

## Reglas del paquete

- Jamás incluir credenciales, rutas personales ni el `opencode.json` personal completo; compartir solo la plantilla o pasar por el merge del instalador.
- Los comandos de uso e instalación documentados en `README.md` son la fuente de verdad; mantén el README y estos ficheros coherentes.
