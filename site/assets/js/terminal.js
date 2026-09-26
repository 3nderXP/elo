(function () {
  "use strict";

  var ROOT = "root";
  var LAUNCH = "elo";

  var MENUS = {
    root: ["Instances", "Addons", "System", "Help", "Exit"],
    Instances: [
      "Create instance",
      "Import modpack",
      "Change instance version",
      "Activate instance",
      "Reset managed links",
      "List instances",
      "Remove instance",
      "Back"
    ],
    Addons: [
      "Search addons",
      "Install addon",
      "List addons",
      "Adopt external addon",
      "Remove addon",
      "Provider settings",
      "Back"
    ],
    System: ["Status", "Update Elo", "Uninstall Elo", "Back"],
    Loader: ["fabric", "neoforge", "forge", "quilt", "vanilla"]
  };

var OUTPUTS = {
    status: {
      cmd: "elo status",
      exit: 1,
      lines: [
        "Minecraft: ~/.minecraft",
        "Active instance: cool-mine",
        "FOLDER           LINK                 ORIGINAL     STATE",
        "mods             cool-mine              backed_up    ok",
        "resourcepacks    cool-mine              backed_up    ok",
        "shaderpacks      cool-mine              backed_up    missing link",
        "config           cool-mine              backed_up    divergent link",
        "saves            cool-mine              backed_up    ok"
      ]
    },
    install: {
      cmd: "elo addons install cool-mine sodium --yes",
      exit: 0,
      lines: [
        "info: Addon progress: 0/1 (0%): sodium-fabric-0.8.13+mc1.21.1.jar",
        "info: Addon progress: 1/1 (100%): sodium-fabric-0.8.13+mc1.21.1.jar",
        "info: Installed: Sodium (sodium-fabric-0.8.13+mc1.21.1.jar)"
      ]
    },
    collision: {
      cmd: "elo addons install cool-mine modmenu --yes",
      exit: 1,
      lines: [
        "error: Resolve addon file collisions before installation."
      ]
    }
  };

  var CHILDREN = {
    Instances: "Instances",
    Addons: "Addons",
    System: "System",
    "Instances/Create instance": "Loader",
    "Instances/Back": "pop",
    "Addons/Back": "pop",
    "System/Back": "pop"
  };

  var TOUR = [
    { wait: 700 },
    { type: LAUNCH, speed: 130 },
    { wait: 500 },
    { enter: true, wait: 800 },
    { down: 2, wait: 240 },
    { enter: true, wait: 700 },
    { out: "status", wait: 2200 },
    { back: true, wait: 600 },
    { up: 1, wait: 200 },
    { enter: true, wait: 700 },
    { down: 1, wait: 220 },
    { enter: true, wait: 700 },
    { out: "collision", wait: 1800 },
    { back: true, wait: 500 },
    { up: 1, wait: 200 },
    { enter: true, wait: 700 },
    { down: 3, wait: 220 },
    { enter: true, wait: 460 },
    { esc: true, wait: 700 },
    { enter: true, wait: 700 },
    { enter: true, wait: 1400 }
  ];

  var REDUCED = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function $(sel, root) {
    return (root || document).querySelector(sel);
  }

  function initTui(root) {
    var screen = $("[data-tui-screen]", root);
    var menu = $("[data-tui-menu]", root);
    var title = $("[data-tui-title]", root);
    var cmdOut = $("[data-tui-cmd]", root);
    var stateOut = $("[data-tui-state]", root);
    var live = $("[data-tui-live]", root);
    var replayBtn = $("[data-tui-replay]", root);
    var outEl = $("[data-tui-out]", root);
    if (!screen || !menu) return;

    var stack = [{ id: ROOT, index: 0 }];
    var phase = "prompt";
    var cmd = "";
    var timers = [];
    var playing = false;
    var lastHit = -1;
    var tourIndex = 0;

    function current() {
      return stack[stack.length - 1];
    }

    function items() {
      return MENUS[current().id] || [];
    }

    function renderPrompt() {
      if (cmdOut) cmdOut.textContent = cmd;
      if (menu) menu.hidden = true;
      if (title) title.hidden = true;
      if (outEl) outEl.hidden = true;
    }

    function renderMenu() {
      var list = items();
      var frame = current();
      var active = frame.index;

      if (cmdOut) cmdOut.textContent = cmd;
      if (menu) menu.hidden = false;
      if (outEl) outEl.hidden = true;

      while (menu.children.length > list.length) {
        menu.removeChild(menu.lastChild);
      }
      while (menu.children.length < list.length) {
        var li = document.createElement("li");
        li.className = "menu__item";
        li.setAttribute("role", "option");
        li.id = "tui-o" + menu.children.length;
        menu.appendChild(li);
      }

      list.forEach(function (label, i) {
        var li = menu.children[i];
        var on = i === active;
        li.textContent = label;
        li.classList.toggle("is-selected", on);
        li.setAttribute("aria-selected", on ? "true" : "false");
        if (on && i !== lastHit) {
          li.classList.remove("is-hit");
          void li.offsetWidth;
          li.classList.add("is-hit");
        }
      });

      lastHit = active;
      menu.setAttribute("aria-activedescendant", "tui-o" + active);

      var where = frame.id === ROOT ? "main menu" : frame.id;
      if (title) {
        title.hidden = frame.id === ROOT;
        title.textContent = frame.id;
      }
      if (stateOut) {
        stateOut.textContent = where + " \u00b7 " + (active + 1) + "/" + list.length;
      }
      if (live) {
        live.textContent = where + ": " + list[active];
      }
    }

    function showOutput(name) {
      var out = OUTPUTS[name];
      if (!out || !outEl) return;
      phase = "out";
      if (cmdOut) cmdOut.textContent = out.cmd;
      if (menu) menu.hidden = true;
      if (title) title.hidden = true;
      if (outEl) {
        outEl.hidden = false;
        outEl.textContent = out.lines.join("\n");
      }
      if (stateOut) {
        stateOut.textContent = out.cmd + " \u00b7 exit " + out.exit;
      }
      if (live) {
        live.textContent = out.cmd + " \u00b7 exit " + out.exit;
      }
    }

    function hideOutput() {
      if (phase !== "out") return;
      phase = "menu";
      renderMenu();
    }

    function renderMenu() {
      var list = items();
      var frame = current();
      var active = frame.index;

      if (cmdOut) cmdOut.textContent = cmd;
      if (menu) menu.hidden = false;

      while (menu.children.length > list.length) {
        menu.removeChild(menu.lastChild);
      }
      while (menu.children.length < list.length) {
        var li = document.createElement("li");
        li.className = "menu__item";
        li.setAttribute("role", "option");
        li.id = "tui-o" + menu.children.length;
        menu.appendChild(li);
      }

      list.forEach(function (label, i) {
        var li = menu.children[i];
        var on = i === active;
        li.textContent = label;
        li.classList.toggle("is-selected", on);
        li.setAttribute("aria-selected", on ? "true" : "false");
        if (on && i !== lastHit) {
          li.classList.remove("is-hit");
          void li.offsetWidth;
          li.classList.add("is-hit");
        }
      });

      lastHit = active;
      menu.setAttribute("aria-activedescendant", "tui-o" + active);

      var where = frame.id === ROOT ? "main menu" : frame.id;
      if (title) {
        title.hidden = frame.id === ROOT;
        title.textContent = frame.id;
      }
      if (stateOut) {
        stateOut.textContent = where + " · " + (active + 1) + "/" + list.length;
      }
      if (live) {
        live.textContent = where + ": " + list[active];
      }
    }

    function paint() {
      if (phase === "menu") renderMenu();
      else renderPrompt();
    }

    function move(delta) {
      if (phase !== "menu") return;
      var frame = current();
      var list = items();
      frame.index = (frame.index + delta + list.length) % list.length;
      renderMenu();
    }

    function jump(where) {
      if (phase !== "menu") return;
      var frame = current();
      frame.index = where === "home" ? 0 : items().length - 1;
      renderMenu();
    }

    function pop() {
      if (phase !== "menu") return;
      if (stack.length > 1) stack.pop();
      renderMenu();
    }

    function openMenu() {
      stack = [{ id: ROOT, index: 0 }];
      lastHit = -1;
      phase = "menu";
      renderMenu();
    }

    function closeMenu() {
      phase = "prompt";
      cmd = "";
      lastHit = -1;
      renderPrompt();
    }

    function activate() {
      if (phase === "prompt") {
        if (cmd.trim() !== LAUNCH) return;
        openMenu();
        return;
      }
      var frame = current();
      var label = items()[frame.index];
      var target = (frame.id === ROOT ? "" : frame.id + "/") + label;
      var next = CHILDREN[target];
      if (next === "pop") {
        pop();
        return;
      }
      if (next) {
        stack.push({ id: next, index: 0 });
        renderMenu();
        return;
      }
      if (label === "Exit") closeMenu();
    }

    function clearTimers() {
      timers.forEach(clearTimeout);
      timers = [];
    }

    function later(fn, ms) {
      timers.push(setTimeout(fn, ms));
    }

    function typeCommand(text, speed, done) {
      cmd = "";
      renderPrompt();
      var i = 0;
      (function step() {
        if (i >= text.length) {
          done();
          return;
        }
        cmd += text.charAt(i);
        renderPrompt();
        i += 1;
        later(step, speed);
      })();
    }

    function halt() {
      clearTimers();
      playing = false;
      root.classList.remove("is-playing");
      if (stateOut) {
        stateOut.textContent = phase === "menu" ? stateOut.textContent : stateOut.dataset.idle;
      }
    }

    function play() {
      clearTimers();
      playing = true;
      root.classList.add("is-playing");
      stack = [{ id: ROOT, index: 0 }];
      phase = "prompt";
      cmd = "";
      lastHit = -1;
      renderPrompt();

      tourIndex = 0;
      (function next() {
        if (tourIndex >= TOUR.length) {
          later(restartTour, 2500);
          return;
        }
        var step = TOUR[tourIndex];
        tourIndex += 1;
        if (step.type) {
          typeCommand(step.type, step.speed, function () {
            later(next, step.wait || 0);
          });
          return;
        }
        if (step.out) {
          showOutput(step.out);
          later(next, step.wait || 0);
          return;
        }
        if (step.back) {
          hideOutput();
          later(next, step.wait || 0);
          return;
        }
        if (step.down) {
          for (var d = 0; d < step.down; d += 1) move(1);
        }
        if (step.up) {
          for (var u = 0; u < step.up; u += 1) move(-1);
        }
        if (step.enter) activate();
        if (step.esc) pop();
        later(next, step.wait || 0);
      })();
    }

    function restartTour() {
      if (!playing) return;
      play();
    }

    function onKey(event) {
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      var key = event.key;

      if (key === "Enter") {
        event.preventDefault();
        halt();
        activate();
      } else if (key === "ArrowDown" || key === "j") {
        event.preventDefault();
        halt();
        move(1);
      } else if (key === "ArrowUp" || key === "k") {
        event.preventDefault();
        halt();
        move(-1);
      } else if (key === "Escape") {
        event.preventDefault();
        halt();
        if (phase === "out") {
          hideOutput();
        } else {
          pop();
        }
      } else if (key === "Home") {
        event.preventDefault();
        halt();
        jump("home");
      } else if (key === "End") {
        event.preventDefault();
        halt();
        jump("end");
      } else if (key === "Backspace") {
        if (phase !== "prompt") return;
        event.preventDefault();
        halt();
        cmd = cmd.slice(0, -1);
        renderPrompt();
      } else if (key.length === 1) {
        if (phase !== "prompt") return;
        event.preventDefault();
        halt();
        cmd += key;
        renderPrompt();
      } else {
        return;
      }

      if (stateOut && phase === "prompt") {
        stateOut.textContent = stateOut.dataset.idle;
      }
    }

    screen.addEventListener("keydown", onKey);
    screen.addEventListener("focus", function () {
      root.classList.add("is-focused");
    });
    screen.addEventListener("blur", function () {
      root.classList.remove("is-focused");
    });
    menu.addEventListener("click", function (event) {
      var li = event.target.closest(".menu__item");
      if (!li || menu.hidden) return;
      halt();
      current().index = Array.prototype.indexOf.call(menu.children, li);
      activate();
    });

    if (replayBtn) {
      replayBtn.addEventListener("click", function () {
        play();
        screen.focus();
      });
    }

    if (stateOut) stateOut.dataset.idle = stateOut.textContent;
    closeMenu();

    if (REDUCED) {
      cmd = LAUNCH;
      openMenu();
      return;
    }

    if ("IntersectionObserver" in window) {
      var seen = false;
      var observer = new IntersectionObserver(
        function (entries) {
          if (seen) return;
          if (!entries[0].isIntersecting) return;
          seen = true;
          observer.disconnect();
          play();
        },
        { threshold: 0.6 }
      );
      observer.observe(root);
    } else {
      play();
    }
  }

  function init() {
    var roots = document.querySelectorAll("[data-tui]");
    Array.prototype.forEach.call(roots, initTui);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
