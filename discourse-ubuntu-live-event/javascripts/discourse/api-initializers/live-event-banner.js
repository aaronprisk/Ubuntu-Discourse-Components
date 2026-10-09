import { apiInitializer } from "discourse/lib/api";
import DiscourseURL from "discourse/lib/url";

export default apiInitializer("1.8.0", (api) => {
  api.onPageChange(() => {
    const s = settings;
    const user = api.getCurrentUser?.();

    // Elements
    const banner    = document.getElementById("community-banner");
    const minimized = document.getElementById("banner-minimized");
    if (!banner || !minimized) return;

    if (banner.dataset.enhanced === "1") return; // avoid double-bind
    banner.dataset.enhanced = "1";

    const dismissBtn  = document.getElementById("dismiss-banner");
    const restoreBtn  = document.getElementById("restore-banner");
    const navBtn      = document.getElementById("custom-nav-btn");
    const chatBtn     = document.getElementById("chat-button");
    const scheduleBtn = document.getElementById("schedule-button");
    const iframe      = banner.querySelector(".banner-video iframe");
    const h2          = banner.querySelector(".banner-text h2");
    const strong      = banner.querySelector(".banner-text strong");
    const p           = banner.querySelector(".banner-text p");
    const miniTextEl  = document.getElementById("banner-minimized-text");
    const toggleBtn = document.getElementById("banner-actions-toggle");
    const drawer    = document.getElementById("banner-actions-drawer");

// --- Mobile CTA Accordion Toggle ---
toggleBtn?.addEventListener("click", () => {
  const isOpen = drawer.classList.toggle("is-open");
  toggleBtn.setAttribute("aria-expanded", isOpen ? "true" : "false");
});

    // --- Helpers ---
    function isSameOrigin(href) {
      if (!href) return false;
      if (href.startsWith("/")) return true;
      try {
        const u = new URL(href, window.location.origin);
        return u.origin === window.location.origin;
      } catch {
        return false;
      }
    }

    // --- Scope logic: global vs summit_only ---
    function inSummitCategory() {
      try {
        const cat = api.getCurrentCategory?.();
        const topic = api.getCurrentTopic?.();
        const current = cat || (topic && topic.category);
        const targetSlug = (s.summit_category_slug || "summit").toLowerCase();
        if (current?.slug && String(current.slug).toLowerCase() === targetSlug) {
          return true;
        }
      } catch (e) {}
      const slug = (s.summit_category_slug || "summit").toLowerCase();
      return window.location.pathname.toLowerCase().startsWith(`/c/${slug}`);
    }

    function scopeAllows() {
      if (!s.banner_enabled) return false;
      if (s.banner_scope === "summit_only") return inSummitCategory();

      const norm = (arr) => (arr || []).map((x) => String(x).trim().toLowerCase()).filter(Boolean);
      const inc = norm(s.include_categories);
      const exc = norm(s.exclude_categories);

      let catId = null;
      let catSlug = null;
      try {
        const cat = api.getCurrentCategory?.();
        const topic = api.getCurrentTopic?.();
        const current = cat || (topic && topic.category);
        if (current?.id) catId = String(current.id);
        if (current?.slug) catSlug = String(current.slug).toLowerCase();
      } catch (e) {}

      const inMatch = () => (catId || catSlug) && (inc.includes(catId?.toLowerCase() || "") || inc.includes(catSlug || ""));
      const exMatch = () => (catId || catSlug) && (exc.includes(catId?.toLowerCase() || "") || exc.includes(catSlug || ""));

      if (inc.length > 0) return inMatch();
      if (s.show_everywhere) return !exMatch();
      return true;
    }

    // --- Apply dynamic content ---
    if (miniTextEl && s.minimized_text) miniTextEl.textContent = s.minimized_text;

    if (iframe && s.youtube_url) {
      const desired = String(s.youtube_url).trim();
      const current = iframe.dataset.currentSrc || iframe.getAttribute("src") || "";
      if (!iframe.dataset.loaded || current !== desired) {
        iframe.src = desired;
        iframe.dataset.loaded = "1";
        iframe.dataset.currentSrc = desired;
      }
    }
    if (h2 && s.event_title) h2.textContent = s.event_title;
    if (strong && s.event_subtitle) strong.textContent = s.event_subtitle;
    if (p && s.event_description) p.textContent = s.event_description;

    if (navBtn) {
      if (s.primary_cta_label) navBtn.textContent = s.primary_cta_label;
      if (s.primary_cta_href) navBtn.href = s.primary_cta_href;
    }
    if (chatBtn) {
      if (s.chat_cta_label) chatBtn.textContent = s.chat_cta_label;
      if (s.chat_cta_href) chatBtn.href = s.chat_cta_href;
    }
    if (scheduleBtn) {
      if (s.schedule_cta_label) scheduleBtn.textContent = s.schedule_cta_label;
      if (s.schedule_cta_href) scheduleBtn.href = s.schedule_cta_href;
    }

    // --- Visibility ---
    function applyVisibility() {
      if (!scopeAllows()) {
        banner.style.display = "none";
        minimized.style.display = "none";
        return;
      }
      const isMin = sessionStorage.getItem("bannerMinimized");
      banner.style.display = isMin ? "none" : "block";
      minimized.style.display = isMin ? "block" : "none";
    }
    applyVisibility();

    // --- Minimize/Restore controls ---
    dismissBtn?.addEventListener("click", () => {
      sessionStorage.setItem("bannerMinimized", "1");
      applyVisibility();
      window.scrollTo({ top: 0, behavior: "smooth" });
    });

    restoreBtn?.addEventListener("click", () => {
      sessionStorage.removeItem("bannerMinimized");
      applyVisibility();
      banner.scrollIntoView({ block: "start", behavior: "smooth" });
    });

    // --- Routing behavior ---
    if (!user) {
      const loginRedirect = (el) => {
        if (!el) return;
        el.onclick = (e) => {
          e.preventDefault();
          const href = el.getAttribute("href") || "/";
          if (isSameOrigin(href)) {
            window.location.href = `/login?redirect=${encodeURIComponent(href)}`;
          } else {
            window.location.href = href;
          }
        };
      };
      [navBtn, chatBtn, scheduleBtn].forEach(loginRedirect);
    } else {
      const bindCTA = (el) => {
        if (!el) return;
        el.onclick = (e) => {
          const href = el.getAttribute("href") || "/";
          if (isSameOrigin(href)) {
            e.preventDefault();
            DiscourseURL.routeTo(href);
          }
        };
      };
      [navBtn, chatBtn, scheduleBtn].forEach(bindCTA);
    }
  });
});
