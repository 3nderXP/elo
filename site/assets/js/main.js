(function () {
  "use strict";

  var REPO = "3nderXP/elo";

  function $(sel, root) {
    return (root || document).querySelector(sel);
  }

  function $$(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.top = "-1000px";
      area.style.opacity = "0";
      document.body.appendChild(area);
      area.select();
      try {
        document.execCommand("copy") ? resolve() : reject(new Error("copy rejected"));
      } catch (err) {
        reject(err);
      } finally {
        document.body.removeChild(area);
      }
    });
  }

  function initCopy() {
    $$("button[data-copy]").forEach(function (button) {
      var source = button.getAttribute("data-copy");
      if (!source) {
        var holder = button.parentNode.querySelector("[data-copy]");
        source = holder ? holder.textContent.trim() : "";
      }
      if (!source) return;
      var timer = null;
      button.addEventListener("click", function () {
        copyText(source).then(
          function () {
            button.classList.add("is-done");
          },
          function () {
            button.classList.add("is-failed");
          }
        );
        clearTimeout(timer);
        timer = setTimeout(function () {
          button.classList.remove("is-done", "is-failed");
        }, 1600);
      });
    });
  }

  function initNav() {
    var toggle = $(".nav-toggle");
    var nav = $("#site-nav");
    if (!toggle || !nav) return;
    function close() {
      nav.classList.remove("is-open");
      toggle.setAttribute("aria-expanded", "false");
    }
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    $$("a", nav).forEach(function (link) {
      link.addEventListener("click", close);
    });
    $$("[data-lang]", nav).forEach(function (button) {
      button.addEventListener("click", close);
    });
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") close();
    });
    document.addEventListener("click", function (event) {
      if (!nav.classList.contains("is-open")) return;
      if (!nav.contains(event.target) && !toggle.contains(event.target)) close();
    });
  }

  function initLangMenu() {
    var menus = $$("[data-lang-menu]");
    if (!menus.length) return;

    function closeAll(keep) {
      menus.forEach(function (menu) {
        if (menu !== keep) menu.removeAttribute("open");
      });
    }

    document.addEventListener("elo:lang", function () {
      closeAll(null);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      var open = menus.filter(function (menu) {
        return menu.hasAttribute("open");
      });
      if (!open.length) return;
      closeAll(null);
      var trigger = $("summary", open[0]);
      if (trigger) trigger.focus();
    });

    document.addEventListener("click", function (event) {
      var inside = menus.filter(function (menu) {
        return menu.contains(event.target);
      });
      closeAll(inside[0] || null);
    });
  }

  function initSpy() {
    var links = $$(".nav a[href^='#']");
    var targets = links
      .map(function (link) {
        return document.getElementById(link.getAttribute("href").slice(1));
      })
      .filter(Boolean);
    if (!targets.length || !("IntersectionObserver" in window)) return;
    var ratios = new Map();
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          ratios.set(entry.target.id, entry.isIntersecting ? entry.intersectionRatio : 0);
        });
        var best = null;
        var bestRatio = 0;
        ratios.forEach(function (ratio, id) {
          if (ratio > bestRatio) {
            bestRatio = ratio;
            best = id;
          }
        });
        links.forEach(function (link) {
          link.classList.toggle("is-current", best !== null && link.getAttribute("href") === "#" + best);
        });
      },
      { rootMargin: "-25% 0px -60% 0px", threshold: [0, 0.25, 0.5, 1] }
    );
    targets.forEach(function (target) {
      observer.observe(target);
    });
  }

  function initVersion() {
    var badges = $$("[data-repo-version]");
    var status = $("[data-release-status]");
    if (!badges.length && !status) return;
    if (!window.fetch) return;

    var shipped = badges.length ? badges[0].textContent.trim() : "";

    fetch("https://api.github.com/repos/" + REPO + "/releases/latest", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then(function (response) {
        if (!response.ok) throw new Error("release lookup failed");
        return response.json();
      })
      .then(function (data) {
        var tag = (data && data.tag_name ? data.tag_name : "").trim();
        if (!/^v?\d/.test(tag)) return;
        if (tag.charAt(0) !== "v") tag = "v" + tag.slice(1);
        badges.forEach(function (badge) {
          badge.textContent = tag;
        });
        if (!status || tag === shipped) return;
        status.textContent = "update available · " + tag;
        status.classList.add("is-shown");
      })
      .catch(function () {
        return;
      });
  }

  initCopy();
  initNav();
  initLangMenu();
  initSpy();
  initVersion();
})();
