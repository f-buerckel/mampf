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
    header.innerHTML = "<h4>Search in Media</h4>";
    
    const closeBtn = document.createElement("span");
    closeBtn.className = "thyme-search-close";
    closeBtn.innerHTML = "&times;";
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
    } else {
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

    this.resultsContainer.innerHTML = "<div class='thyme-search-loading'>Searching...</div>";
    
    try {
      const response = await fetch(`/media/${this.mediumId}/search_content?query=${encodeURIComponent(query)}`);
      
      if (!response.ok) {
        throw new Error("Search failed");
      }

      const results = await response.json();
      this.renderResults(results);
    } catch (error) {
      this.resultsContainer.innerHTML = "<div class='thyme-search-error'>Error loading results. Please try again.</div>";
    }
  }

  renderResults(results) {
    this.resultsContainer.innerHTML = "";

    let items = Array.isArray(results) ? results : (results.results || results.data || []);

    if (items.length === 0) {
      this.resultsContainer.innerHTML = "<div class='thyme-search-no-results'>No results found.</div>";
      return;
    }

    items.forEach(item => {
      // Robust field extraction depending on backend schema
      const time = item.start_time || item.time || item.timestamp || 0;
      const text = item.content || item.text || item.description || "Match found";

      const resultElement = document.createElement("div");
      resultElement.className = "thyme-search-result-item";
      
      const timeLabel = document.createElement("span");
      timeLabel.className = "thyme-search-result-time";
      
      let relevanceHtml = "";
      const relevance = item.rerank_score || item.rrf_score;
      if (relevance) {
        relevanceHtml = `<small style="color: #6c757d; margin-left: 8px;">Relevanz: ${(relevance * 100).toFixed(2)}%</small>`;
      }
      
      timeLabel.innerHTML = secondsToTime(time) + relevanceHtml;
      
      const textLabel = document.createElement("span");
      textLabel.className = "thyme-search-result-text";
      textLabel.innerHTML = text;

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
}
