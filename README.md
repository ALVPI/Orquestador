# Orquestación multi-agente para OpenCode

Paquete reutilizable con un agente orquestador + 5 subagentes especializados,
basado en la configuración global (V2) de OpenCode.

## Contenido

```text
.
├── install.sh                        ← instalación en tu config global (~/.config/opencode/)
├── opencode-global.example.json      ← plantilla de opencode.json (referencia / instalación limpia)
├── agents/                           ← orquestador + 5 subagentes compartidos por ambos usos
└── proyecto/
    └── .opencode/                    ← cópialo tal cual a la raíz de un repositorio de equipo
        ├── opencode.json
        └── agents/
```

| Agente | Rol |
|---|---|
| `orchestrator` | Agente principal (`primary`): clasifica la tarea y delega |
| `code` | Programación: implementa, refactoriza, pruebas |
| `debug` | Diagnóstico y corrección de errores |
| `research` | Investigación y fuentes |
| `review` | Auditoría de código |
| `architect` | Diseño y planificación |

## Opción A — Proyecto de equipo (sin instalar nada)

Copia `proyecto/.opencode/` a la raíz de tu repositorio y haz commit:

```sh
cp -R proyecto/.opencode /ruta/al/repo/
cd /ruta/al/repo && git add .opencode && git commit -m "Añade orquestación multi-agente de OpenCode"
```

Todo el que clone el repo y abra OpenCode ahí recibe los agentes y la config
automáticamente. No toca la configuración personal de nadie.

## Opción B — Config global personal (para cualquier directorio)

```sh
git clone <este-repo> opencode-multiagente
cd opencode-multiagente && ./install.sh
```

El instalador:

1. Copia los agentes a `~/.config/opencode/agents/` (backup previo si sobrescribe).
2. Si no tienes `opencode.json`, la crea desde la plantilla.
3. Si ya la tienes: **respeta tu modelo, tu agente por defecto y tus permisos
   existentes**. Solo añade las reglas cuya acción no hayas personalizado;
   nunca debilita ni sobrescribe lo que ya tengas configurado.

## Requisitos para quien lo usa

- OpenCode V2 (la config usa `permissions`, no las claves deprecadas de V1).
- Autenticar su propia cuenta de OpenCode una vez, para que el proveedor
  `opencode` (modelos gratuitos, p. ej. `glm-5.3-flash-free`) esté disponible.
  El paquete **no incluye credenciales** y no debe incluirlas nunca.

## Seguridad

- No se comparte nunca tu `opencode.json` personal completo: borrarías la
  configuración del otro. Comparte la plantilla o usa el merge del instalador.
- Revisa el contenido antes de publicar el bundle: nada de rutas personales
  ni secretos. Reglas del paquete: `edit` en `allow` (operando sobre el cwd
  del proyecto invocado); `shell` en `ask`, con excepciones de solo lectura
  (`git status`, `git diff`, `git log`, `git branch`, `ls`) para no
  entorpecer el flujo; `subagent`, `webfetch` y `external_directory` en
  `ask`. El paquete **no** añade reglas `read` en blanco, así que la
  protección `.env` integrada de OpenCode sigue activa. En `shell`, la opción
  "Allow always" guarda prefijos de comando por proyecto.
