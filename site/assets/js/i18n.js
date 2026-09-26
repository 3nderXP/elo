(function () {
  "use strict";

  var STORE_KEY = "elo.lang";
  var DEFAULT = "en";

  function $(sel, root) {
    return (root || document).querySelector(sel);
  }

  function $$(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function catalog(tag) {
    return (window.ELO_I18N && window.ELO_I18N[tag]) || null;
  }

  function read() {
    try {
      return window.localStorage.getItem(STORE_KEY);
    } catch (err) {
      return null;
    }
  }

  function write(tag) {
    try {
      window.localStorage.setItem(STORE_KEY, tag);
    } catch (err) {
      return;
    }
  }

  function detect() {
    var saved = read();
    if (saved && (saved === DEFAULT || catalog(saved))) return saved;
    var tags = Object.keys(window.ELO_I18N || {});
    if (!tags.length) return DEFAULT;
    var wanted = navigator.languages || [navigator.language || DEFAULT];
    for (var i = 0; i < wanted.length; i += 1) {
      var tag = String(wanted[i]).toLowerCase();
      for (var j = 0; j < tags.length; j += 1) {
        var have = String(tags[j]).toLowerCase();
        if (have === tag || have.split("-")[0] === tag.split("-")[0]) return tags[j];
      }
    }
    return DEFAULT;
  }

  function has(dict, key) {
    return Object.prototype.hasOwnProperty.call(dict, key);
  }

  var ORIGINAL = new WeakMap();

  function original(el) {
    var rec = ORIGINAL.get(el);
    if (!rec) {
      rec = {
        html: el.innerHTML,
        aria: el.getAttribute("aria-label"),
        content: el.getAttribute("content")
      };
      ORIGINAL.set(el, rec);
    }
    return rec;
  }

  function apply(tag) {
    var dict = tag === DEFAULT ? null : catalog(tag);
    document.documentElement.lang = tag === DEFAULT ? "en" : tag;

    $$("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      var base = original(el);
      el.innerHTML = dict && has(dict, key) ? dict[key] : base.html;
    });

    $$("[data-i18n-aria-label]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-aria-label");
      var base = original(el);
      if (dict && has(dict, key)) {
        el.setAttribute("aria-label", dict[key]);
      } else if (base.aria !== null) {
        el.setAttribute("aria-label", base.aria);
      }
    });

    $$("[data-i18n-content]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-content");
      var base = original(el);
      if (dict && has(dict, key)) {
        el.setAttribute("content", dict[key]);
      } else if (base.content !== null) {
        el.setAttribute("content", base.content);
      }
    });

    $$("[data-lang]").forEach(function (el) {
      var on = el.getAttribute("data-lang") === tag;
      el.classList.toggle("is-active", on);
      if (on) {
        el.setAttribute("aria-current", "true");
      } else {
        el.removeAttribute("aria-current");
      }
    });

    return Boolean(dict);
  }

  function init() {
    var links = $$("[data-lang]");
    var tag = detect();
    var ok = apply(tag);

    if (!ok && tag !== DEFAULT) {
      apply(DEFAULT);
    }

    links.forEach(function (link) {
      link.addEventListener("click", function (event) {
        event.preventDefault();
        var want = link.getAttribute("data-lang");
        var applied = apply(want);
        if (!applied && want !== DEFAULT) return;
        write(want);
        document.dispatchEvent(new CustomEvent("elo:lang", { detail: { lang: want } }));
      });
    });

    window.addEventListener("storage", function (event) {
      if (event.key !== STORE_KEY || !event.newValue) return;
      apply(event.newValue);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
