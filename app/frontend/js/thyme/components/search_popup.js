import { secondsToTime } from "../utility";

export class SearchPopup {
  constructor(mediumId, videoElement) {
    this.mediumId = mediumId;
    this.videoElement = videoElement;
    this.container = null;
    this.input = null;
    this.resultsContainer = null;
    this.isVisible = false;

    this.createDomElements();
    this.addEventListeners();
  }

  createDomElements() {
    this.container = document.createElement("div");
    this.container.className = "thyme-search-popup";
    this.container.style.display = "none";

    const wrapper = document.createElement("div");
    wrapper.className = "thyme-search-wrapper";

    const header = document.createElement("div");
    header.className = "thyme-search-header";

    const title = document.createElement("h4");
    title.textContent = "Search in Media";
    header.appendChild(title);

    const closeBtn = document.createElement("span");
    closeBtn.className = "thyme-search-close";
    closeBtn.textContent = "×";
    closeBtn.onclick = () => this.hide();
    header.appendChild(closeBtn);

    const inputWrapper = document.createElement("div");
    inputWrapper.className = "thyme-search-input-wrapper";

    this.input = document.createElement("input");
    this.input.type = "text";
    this.input.className = "thyme-search-input";
    this.input.placeholder = "Search for terms... (Press Enter to search)";

    inputWrapper.appendChild(this.input);

    this.resultsContainer = document.createElement("div");
    this.resultsContainer.className = "thyme-search-results";

    wrapper.appendChild(header);
    wrapper.appendChild(inputWrapper);
    wrapper.appendChild(this.resultsContainer);
    this.container.appendChild(wrapper);

    // Append to document body or player container
    document.body.appendChild(this.container);
  }

  addEventListeners() {
    this.input.addEventListener("keydown", (e) => {
      // Prevent other player shortcuts from triggering when typing in search
      e.stopPropagation();

      if (e.key === "Enter") {
        this.performSearch();
      }
      if (e.key === "Escape") {
        this.hide();
      }
    });

    // Close when clicking outside the wrapper
    this.container.addEventListener("click", (e) => {
      if (e.target === this.container) {
        this.hide();
      }
    });
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
    this.container.style.display = "flex";
    this.input.focus();
    // lock shortcuts to avoid hitting other player keys
    window.thymeAttributes = window.thymeAttributes || {};
    this.previousLockState = window.thymeAttributes.lockKeyListeners;
    window.thymeAttributes.lockKeyListeners = true;
  }

  hide() {
    this.isVisible = false;
    this.container.style.display = "none";
    // restore key listeners
    if (window.thymeAttributes) {
      window.thymeAttributes.lockKeyListeners = this.previousLockState || false;
    }
    // bring focus back to player/body so shortcuts work again
    document.body.focus();
  }

  async performSearch() {
    const query = this.input.value.trim();
    if (!query) return;

    this.resultsContainer.replaceChildren();
    const loading = document.createElement("div");
    loading.className = "thyme-search-loading";
    loading.textContent = "Searching...";
    this.resultsContainer.appendChild(loading);

    try {
      const response = await fetch(`/media/${this.mediumId}/search_content?query=${encodeURIComponent(query)}`);

      if (!response.ok) {
        throw new Error("Search failed");
      }

      const results = await response.json();
      this.renderResults(results);
    }
    catch {
      this.resultsContainer.replaceChildren();
      const errorElement = document.createElement("div");
      errorElement.className = "thyme-search-error";
      errorElement.textContent = "Error loading results. Please try again.";
      this.resultsContainer.appendChild(errorElement);
    }
  }

  renderResults(results) {
    this.resultsContainer.replaceChildren();

    const items = Array.isArray(results) ? results : [];

    if (items.length === 0) {
      const noResults = document.createElement("div");
      noResults.className = "thyme-search-no-results";
      noResults.textContent = "No results found.";
      this.resultsContainer.appendChild(noResults);
      return;
    }

    items.forEach((item) => {
      const time = Number(item.start_time);
      const relevance = item.rerank_score ?? item.rrf_score;

      const resultElement = document.createElement("div");
      resultElement.className = "thyme-search-result-item";

      const timeLabel = document.createElement("span");
      timeLabel.className = "thyme-search-result-time";
      timeLabel.textContent = secondsToTime(time);

      if (Number.isFinite(relevance)) {
        const relevanceLabel = document.createElement("small");
        relevanceLabel.style.color = "#6c757d";
        relevanceLabel.style.marginLeft = "8px";
        relevanceLabel.textContent = `Relevanz: ${(relevance * 100).toFixed(2)}%`;
        timeLabel.appendChild(relevanceLabel);
      }

      const textLabel = document.createElement("span");
      textLabel.className = "thyme-search-result-text";
      this.renderText(textLabel, item);

      resultElement.appendChild(timeLabel);
      resultElement.appendChild(textLabel);

      resultElement.onclick = () => {
        this.videoElement.currentTime = time;
        this.videoElement.play();
        this.hide();
      };

      this.resultsContainer.appendChild(resultElement);
    });
  }

  renderText(container, item) {
    item.highlight_segments.forEach((segment) => {
      const span = document.createElement("span");
      span.textContent = segment.text;
      if (segment.color) {
        span.style.backgroundColor = segment.color;
      }
      container.appendChild(span);
    });
  }
}
