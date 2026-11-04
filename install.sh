#!/usr/bin/env bash
# Instala la orquestación multi-agente en la configuración GLOBAL del usuario.
# Uso:  git clone <repo> && cd multiagente && ./install.sh
#
# - Copia los agentes a ~/.config/opencode/agents/ (con copia previa si existían).
# - Si no existe ~/.config/opencode/opencode.json, la crea desde la plantilla.
# - Si existe, AÑADE solo las reglas de permisos cuya acción no hayas
#   personalizado (nunca modifica ni debilita tus reglas existentes);
#   respeta tu modelo por defecto y tu default_agent.
#
# Para instalar en otra ruta (p. ej. para pruebas): OPENCODE_CONFIG_DIR=/alguna/ruta ./install.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SRC="$SRC_DIR/agents"
DEST_CONFIG="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
DEST_AGENTS="$DEST_CONFIG/agents"

if [ ! -d "$AGENTS_SRC" ]; then
  echo "ERROR: no se encuentra la carpeta de agentes en $AGENTS_SRC" >&2
  exit 1
fi

echo "== Instalando agentes en $DEST_AGENTS =="
mkdir -p "$DEST_AGENTS"

# Copia previa de los agentes preexistentes que se vayan a sobrescribir
BACKUP="$DEST_CONFIG/agents.bak.$(date +%Y%m%d-%H%M%S)"
OVERWRITTEN=0
for f in "$AGENTS_SRC"/*.md; do
  name="$(basename "$f")"
  if [ -f "$DEST_AGENTS/$name" ]; then
    mkdir -p "$BACKUP"
    cp "$DEST_AGENTS/$name" "$BACKUP/$name"
    OVERWRITTEN=$((OVERWRITTEN + 1))
  fi
done
if [ "$OVERWRITTEN" -gt 0 ]; then
  echo "Sobrescribidos $OVERWRITTEN agente(s); copia previa en: $BACKUP"
fi

cp "$AGENTS_SRC"/*.md "$DEST_AGENTS/"
echo "Agentes instalados en $DEST_AGENTS"

echo "== Configurando $DEST_CONFIG/opencode.json =="
DEST_CONFIG="$DEST_CONFIG" SRC_DIR="$SRC_DIR" python3 - <<'PY'
import json, os, sys

dest = os.environ["DEST_CONFIG"]
src = os.environ["SRC_DIR"]
path = os.path.join(dest, "opencode.json")

rules = [
    {"action": "edit", "resource": "*", "effect": "allow"},
    {"action": "shell", "resource": "*", "effect": "ask"},
    {"action": "shell", "resource": "git status *", "effect": "allow"},
    {"action": "shell", "resource": "git diff *", "effect": "allow"},
    {"action": "shell", "resource": "git log *", "effect": "allow"},
    {"action": "shell", "resource": "git branch *", "effect": "allow"},
    {"action": "shell", "resource": "ls *", "effect": "allow"},
    {"action": "external_directory", "resource": "*", "effect": "ask"},
    {"action": "webfetch", "resource": "*", "effect": "ask"},
    {"action": "subagent", "resource": "*", "effect": "ask"},
]

def dump(cfg):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
        f.write("\n")

if not os.path.exists(path):
    with open(os.path.join(src, "opencode-global.example.json"), encoding="utf-8") as f:
        cfg = json.load(f)
    dump(cfg)
    print("No existia opencode.json: creada desde la plantilla de referencia.")
    sys.exit(0)

with open(path, encoding="utf-8") as f:
    cfg = json.load(f)

any_change = False

# default_agent: solo si el usuario no tenia uno definido
if cfg.get("default_agent") in (None, ""):
    cfg["default_agent"] = "orchestrator"
    any_change = True
    print("default_agent asignado: orchestrator")
else:
    print(f"default_agent existente respetado: {cfg['default_agent']}")

existing = cfg.setdefault("permissions", [])
if not isinstance(existing, list):
    print("AVISO: 'permissions' no es una lista en tu opencode.json (config antigua?). "
          "No he tocado los permisos; revisalo a mano y sentite libre de usar "
          "opencode-global.example.json como referencia.")
else:
    # Respeta cualquier acción que el usuario ya haya personalizado: si tiene
    # al menos una regla para esa acción, no se añade ninguna regla del
    # paquete de esa acción (nunca se sobrescribe ni se debilita lo existente).
    user_actions = {r.get("action") for r in existing if isinstance(r, dict)}
    added = respected = 0
    for rule in rules:
        if rule["action"] in user_actions:
            respected += 1
            continue
        existing.append(rule)
        added += 1
    if added:
        any_change = True
        print(f"{added} regla(s) anadida(s); {respected} regla(s) del paquete respetadas por tener acciones personalizadas; total: {len(existing)}.")
    else:
        print("Tus permisos ya cubren las acciones del paquete (tienes reglas propias): nada que cambiar.")

if any_change:
    dump(cfg)
    print("opencode.json actualizado.")
else:
    print("opencode.json sin cambios.")
PY

echo
echo "Listo. OpenCode recarga la configuración automáticamente: no hace falta reiniciar."
echo "Esta instalación aplica a TODOS tus directorios y proyectos."
