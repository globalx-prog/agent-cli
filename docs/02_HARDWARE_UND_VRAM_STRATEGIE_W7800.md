# ⚡ AMD Radeon PRO W7800 Hardware-, Modus- & VRAM-Strategie (48 GB)
## Single-Model-per-Mode Architektur: 1 Modell pro Modus = 0x Nachladen

> **Grafikkarte:** AMD Radeon PRO W7800 (48 GB GDDR6 VRAM, 384-Bit Speicherbus, 864 GB/s Bandbreite, Netto ~44,4 GiB)  
> **Architektur:** RDNA 3 (Navi 31 / `gfx1100`) mit ROCm 6.4 nativ  
> **Host-Ressourcen:** 16 CPU-Kerne | 128 GB DDR5 System-RAM | 36 GB NVMe-Swap | Ubuntu Linux  
> **Goldenes Architektur-Prinzip:** **Jeder Modus weist exakt EIN Modell allen Rollen zu (`Build`, `small_model`, `@planner`, `@coder`, `@tester`, `@reviewer`).** Dadurch wird das Modell nur 1x beim Start in den VRAM geladen und während der gesamten Session **niemals** entladen!

---

## 🎯 1. Warum „1 Modell pro Modus“ auf 48 GB VRAM entscheidend ist

In `/etc/systemd/system/ollama.service` ist `OLLAMA_MAX_LOADED_MODELS=1` gesetzt (und große Modelle belegen 21–42 GB VRAM).  
Würden Hauptagent, `small_model` (für Chat-Titel) und `@planner` unterschiedliche Modelle verwenden, müsste die W7800 bei jedem Schritt 33–42 GB aus dem VRAM löschen und von der SSD neu einlesen (~12–18 Sekunden Pause pro Wechsel).

### Die Lösung in diesem Setup:
1. In [`planner.md`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/agents/planner.md), [`coder.md`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/agents/coder.md), [`tester.md`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/agents/tester.md) und [`reviewer.md`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/agents/reviewer.md) ist **kein festes Modell** mehr hartcodiert – alle Spezial-Agenten **erben automatisch** das aktive Modus-Modell aus [`opencode.json`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/opencode.json)!
2. Wenn du in [`scripts/start_agent_session.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/start_agent_session.sh) einen der **5 Modi** wählst, setzt das Startskript automatisch sowohl `"model"` als auch `"small_model"` auf dieses eine Modell und räumt vorab den anderen Port frei.
3. **Ergebnis:** **0,0 Sekunden Wechselzeit** zwischen `Build`, `/plan`, `/review`, `/webtest`, `@planner`, `@coder`, `@tester` und `@reviewer`!

---

## 📊 2. Die 6 Modi im Überblick (Maximierter 100%-VRAM Default-Kontext pro Modus)

Dank `OLLAMA_KV_CACHE_TYPE=q4_0` (und `-ctk q4_0 -ctv q4_0` in `llama-speedup`) belegt der Kontextspeicher 75 % weniger VRAM als unter FP16. Dadurch sind alle Modi auf ihren **maximal sicheren 100%-VRAM-Kontext** (unter Wahrung der 41–43 GiB Sicherheitsgrenze der W7800) voreingestellt:

| Modus in `start_agent_session.sh` | Zugewiesenes Modell | Backend & Port | VRAM-Bedarf (inkl. Max-KV) | Freier VRAM-Puffer | Maximierter Default-Kontext | Reale Speed (W7800) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Modus 1: 💻 Coding Quality 64k** *(Standard)* | `ollama/qwen3-coder-quality` *(30.5B MoE Q8_0)* | Ollama (`11434`) | **~35,5 GB** *(32,0+3,5)* | **+9,5 GB frei** | **`64k` (`65.536`)** *(verdoppelt!)* | **62,7 t/s** *(1773 t/s Prefill)* |
| **Modus 2: ⚡ Coding Speed 128k** *(Ultra-Kontext!)* | `ollama/qwen3-coder-speed` *(30.5B MoE Q4_K_M)* | Ollama (`11434`) | **~24,5 GB** *(18,5+6,0)* | **+20,5 GB frei** | **`128k (!)` (`131.072`)** *(4x größer!)* | **80,6 t/s** *(1573 t/s Prefill)* |
| **Modus 3: 🧠 Allround Distill 96k** | `ollama/qwen3.8-35b-distill` *(35B A3B Q6_K)* | Ollama (`11434`) | **~33,0 GB** *(25,5+7,5)* | **+12,0 GB frei** | **`96k` (`98.304`)** *(+50% größer!)* | **66,6 t/s** *(1750 t/s Prefill)* |
| **Modus 4: 👑 72B Speculative 32k** | `llama-speedup/qwen2.5-72b-speculative` *(IQ4_XS + 0.5B)* | `llama-speedup` (`5002`) | **~43,5 GB** *(40,3+3,2)* | **+1,5 GB frei** | **`32k` (`32.768`)** *(100% VRAM-Max)* | **33,6 t/s** *(+269 % Speedup)* |
| **Modus 5: 🔓 70B Unzensiert 32k** | `llama-speedup/llama3.3-70b-abliterated-speculative` | `llama-speedup` (`5002`) | **~42,0 GB** *(39,0+3,0)* | **+3,0 GB frei** | **`32k` (`32.768`)** *(100% VRAM-Max)* | **30,0 t/s** *(+201 % Speedup)* |
| **Modus 6: 🏆 Multi-Model Großprojekt** | `@planner`=70B(`32k`), `Build`=Speed(`128k`), `@coder`=Q8(`64k`), `@reviewer`=70B(`32k`) | Ollama / Hybrid | **24,5–42 GB** *(wechselt)* | **+3 bis +20 GB** | **`32k bis 128k`** *(je nach Phase)* | **13–80 t/s** |

*(Zusatz-Optimierung auf Port 5002: `deepseek-r1-70b-speculative` nutzt ohne Draft-Modell jetzt **`40k` (`40.960`)** Kontext, und `qwen2.5-coder-32b-speculative` nutzt **`64k` (`65.536`)** Kontext).*

---

## 🚀 3. Warum `qwen3-coder-speed` ideal für große Kontexte (64k+) ist & `Qwen3-Next-80B` die DeepSeek-Alternative wird

### A. Warum `qwen3-coder-speed` der Champion für große Kontexte (64k–96k) ist
* **Gewichte belegen nur ~18,5 GB VRAM:** Während Q8-Modelle (33,5 GB) oder 70B-Modelle (40+ GB) den VRAM fast füllen, lässt `qwen3-coder-speed` (`Q4_K_M`) auf der 48 GB W7800 **über 25 GB VRAM frei für den KV-Cache (Kontextspeicher)**!
* **Blitzschneller MoE-Prefill (1.573 t/s):** Weil pro Token nur 3,3B von 30,5B Parametern aktiv sind, liest es einen riesigen 64.000-Token-Kontext in wenigen Sekunden ein (während ein dichtes 70B-Modell dafür über 2 Minuten bräuchte).
* **Automatisch auf 64k (`num_ctx 65536`) gepatcht:** Unser Skript [`scripts/fix_ollama_tool_templates.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/fix_ollama_tool_templates.sh) konfiguriert `qwen3-coder-speed` automatisch mit **64k Kontext** und 16k Output-Tokens.

### B. `Qwen3-Next-80B` (`next80b-32k`) als zukünftige DeepSeek-R1-70B-Alternative
* **Das Problem mit `deepseek-r1-70b-speed`:** Es basiert auf einem dichten (Dense) 70B-Modell (13,1 t/s) und erzeugt vor jedem Tool-Call lange `<think>`-Monologe, die den Kontext füllen und JSON-Tool-Calls verlangsamen.
* **Der Vorteil von `Qwen3-Next-80B` (MoE-Architektur):**
  1. **80B-Wissensbasis bei MoE-Geschwindigkeit:** Kombiniert das tiefe Architektur-Wissen der 80B-Klasse mit deutlich weniger aktiven Parametern pro Token.
  2. **Sauberes, natives Tool-Calling:** Beherrscht das Qwen3-JSON-Tool-Format nativ ohne kaputte `<think>`-Schleifen.
  3. Bereits in [`configs/opencode.json`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/opencode.json) (`ollama/next80b-32k`) und in [`scripts/multimodel_project_workflow.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/multimodel_project_workflow.sh) (`enable-next80b`) hinterlegt!

---

## 🔄 3. Was passiert beim Start eines Modus automatisch?

```text
Auswahl in ./scripts/start_agent_session.sh:
  ├── Modus 1, 2 oder 3 gewählt (Ollama Port 11434):
  │     1. Entlädt automatisch Port 5002 (free_agent_vram.sh --only-speedup)
  │     2. Schreibt gewähltes Modell in opencode.json ("model" + "small_model")
  │     3. Alle @Subagents erben dieses Modell -> 0x Entladen während der Arbeit!
  │
  └── Modus 4 oder 5 gewählt (llama-speedup Port 5002):
        1. Entlädt automatisch Ollama Port 11434 (free_agent_vram.sh --only-ollama)
        2. Schreibt gewähltes 70B/72B-Speculative-Modell in opencode.json
        3. Alle @Subagents erben dieses 70B/72B-Modell -> 0x Entladen während der Arbeit!
```

---

## ⚙️ 4. Thermik & Power-Limit Stellschrauben (Taste `8` & `9` im Launcher)

* **Taste `8` — Hochleistungs-Modus (`230W Uncapped` + 65 % Performance-Lüfter):**
  - Bringt **+18 % schnelleres Prompt-Processing (Prefill)** bei großen Codebasen.
  - Senkt die Hotspot-Temperatur unter Volllast von 98 °C auf **~74 °C (-24 °C)**.
* **Taste `9` — Tagesbetrieb (`200W` + Balanced Lüfter):**
  - Flüsterleise (~34–42 dB) für normale Coding-Sessions.
