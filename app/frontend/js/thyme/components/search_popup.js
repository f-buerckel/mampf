import { secondsToTime } from "../utility";
import { errorMessage, renderHighlightSegments } from "../../search_client_utils";

const DEFAULT_LABELS = {
  title: "Search in media",
  placeholder: "Search for terms… (press Enter to search)",
  searching: "Searching…",
  no_results: "No results found.",
  error: "Error loading results. Please try again.",
  close: "Close search",
  relevance: "Relevance: %{score}%",
  play_from: "Play video from %{time}",
};

export class SearchPopup {
  constructor(mediumId, videoElement, labels = {}) {
    this.mediumId = mediumId;
    this.videoElement = videoElement;
    this.labels = { ...DEFAULT_LABELS, ...labels };
    this.container = null;
    this.input = null;
    this.resultsContainer = null;
    this.isVisible = false;
    this.previousFocus = null;

    this.createDomElements();
    this.addEventListeners();
  }

  createDomElements() {
    this.container = document.createElement("div");
    this.container.className = "thyme-search-popup";
    this.container.style.display = "none";
    this.container.setAttribute("role", "dialog");
    this.container.setAttribute("aria-modal", "true");

    const wrapper = document.createElement("div");
    wrapper.className = "thyme-search-wrapper";

    const header = document.createElement("div");
    header.className = "thyme-search-header";

    const title = document.createElement("h4");
    title.id = "thyme-search-title";
    title.textContent = this.labels.title;
    this.container.setAttribute("aria-labelledby", title.id);
    header.appendChild(title);

    const closeBtn = document.createElement("button");
    closeBtn.type = "button";
    closeBtn.className = "thyme-search-close";
    closeBtn.textContent = "\u00d7";
    closeBtn.setAttribute("aria-label", this.labels.close);
    closeBtn.addEventListener("click", () => this.hide());
    header.appendChild(closeBtn);

    const inputWrapper = document.createElement("div");
    inputWrapper.className = "thyme-search-input-wrapper";

    this.input = document.createElement("input");
    this.input.type = "text";
    this.input.className = "thyme-search-input";
    this.input.placeholder = this.labels.placeholder;

    inputWrapper.appendChild(this.input);

    this.resultsContainer = document.createElement("div");
    this.resultsContainer.className = "thyme-search-results";

    wrapper.appendChild(header);
    wrapper.appendChild(inputWrapper);
    wrapper.appendChild(this.resultsContainer);
    this.container.appendChild(wrapper);

    document.body.appendChild(this.container);
  }

  addEventListeners() {
    this.input.addEventListener("keydown", (e) => {
      e.stopPropagation();
      if (e.key === "Enter") {
        this.performSearch();
      }
      else if (e.key === "Escape") {
        this.hide();
      }
      else if (e.key === "Tab") {
        this.trapFocus(e);
      }
    });

    this.container.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.preventDefault();
        this.hide();
      }
      else if (e.key === "Tab") {
        this.trapFocus(e);
      }
    });

    this.container.addEventListener("click", (e) => {
      if (e.target === this.container) {
        this.hide();
      }
    });
  }

  trapFocus(event) {
    const focusable = this.container.querySelectorAll(
      "button:not([disabled]), input:not([disabled])",
    );
    if (focusable.length === 0) return;

    const first = focusable[0];
    const last = focusable[focusable.length - 1];

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    }
    else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  toggle() {
    if (this.isVisible) {
      this.hide();
    }
    else {
      this.show();
    }
  }

  show() {
    this.isVisible = true;
    this.previousFocus = document.activeElement;
    this.container.style.display = "flex";
    this.input.focus();
    window.thymeAttributes = window.thymeAttributes || {};
    this.previousLockState = window.thymeAttributes.lockKeyListeners;
    window.thymeAttributes.lockKeyListeners = true;
  }

  hide() {
    this.isVisible = false;
    this.container.style.display = "none";
    if (window.thymeAttributes) {
      window.thymeAttributes.lockKeyListeners = this.previousLockState || false;
    }
    if (this.previousFocus
        && typeof this.previousFocus.focus === "function"
        && this.previousFocus.isConnected) {
      this.previousFocus.focus();
    }
    else {
      document.body.focus();
    }
  }

  destroy() {
    this.isVisible = false;
    if (window.thymeAttributes) {
      window.thymeAttributes.lockKeyListeners = this.previousLockState || false;
    }
    if (this.container) {
      this.container.remove();
      this.container = null;
    }
    this.input = null;
    this.resultsContainer = null;
  }

  async performSearch() {
    const query = this.input.value.trim();
    if (!query) return;

    this.resultsContainer.replaceChildren();
    const loading = document.createElement("div");
    loading.className = "thyme-search-loading";
    loading.textContent = this.labels.searching;
    this.resultsContainer.appendChild(loading);

    try {
      const response = await fetch(
        `/media/${this.mediumId}/search_content?query=${encodeURIComponent(query)}`,
        { redirect: "manual" },
      );

      if (!response.ok || response.redirected) {
        throw new Error(await errorMessage(response));
      }

      const body = await response.json();
      const results = Array.isArray(body) ? body : [];
      this.renderResults(results);
    }
    catch (error) {
      this.resultsContainer.replaceChildren();
      const errorElement = document.createElement("div");
      errorElement.className = "thyme-search-error";
      errorElement.textContent = error.message || this.labels.error;
      this.resultsContainer.appendChild(errorElement);
    }
  }

  renderResults(results) {
    this.resultsContainer.replaceChildren();

    const items = Array.isArray(results) ? results : [];

    if (items.length === 0) {
      const noResults = document.createElement("div");
      noResults.className = "thyme-search-no-results";
      noResults.textContent = this.labels.no_results;
      this.resultsContainer.appendChild(noResults);
      return;
    }

    items.forEach((item) => {
      const time = Number(item.start_time);
      const relevance = Number(item.rerank_score ?? item.rrf_score);

      const resultElement = document.createElement("button");
      resultElement.type = "button";
      resultElement.className = "thyme-search-result-item";
      resultElement.setAttribute(
        "aria-label",
        this.labels.play_from.replace("%{time}", secondsToTime(time)),
      );

      const timeLabel = document.createElement("span");
      timeLabel.className = "thyme-search-result-time";
      timeLabel.textContent = secondsToTime(time);

      if (Number.isFinite(relevance)) {
        const clamped = Math.min(Math.max(relevance, 0), 1);
        const percentage = clamped * 100;
        const relevanceLabel = document.createElement("small");
        relevanceLabel.style.color = "#6c757d";
        relevanceLabel.style.marginLeft = "8px";
        relevanceLabel.textContent = this.labels.relevance
          .replace("%{score}", percentage.toFixed(2));
        timeLabel.appendChild(relevanceLabel);
      }

      const textLabel = document.createElement("span");
      textLabel.className = "thyme-search-result-text";
      this.renderText(textLabel, item);

      resultElement.appendChild(timeLabel);
      resultElement.appendChild(textLabel);

      resultElement.addEventListener("click", () => {
        this.videoElement.currentTime = time;
        this.videoElement.play();
        this.hide();
      });

      this.resultsContainer.appendChild(resultElement);
    });
  }

  renderText(container, item) {
    renderHighlightSegments(container, item.highlight_segments);
  }
}
