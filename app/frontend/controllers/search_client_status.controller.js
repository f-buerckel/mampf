import { Controller } from "@hotwired/stimulus";
import { secondsToTime } from "../js/thyme/utility";
import { errorMessage, renderHighlightSegments } from "../js/search_client_utils";

/**
 * Fetches MampfSearch data in the background so that no page render is ever
 * blocked by a connection attempt. It intercepts the form submit, appends the
 * query as `?search=...` and renders the returned JSON results (lecture content
 * search).
 *
 * During the request the `status` target shows a "searching…" text. On failure
 * (non-2xx, redirect, or malformed/non-JSON response) the localized
 * `unavailable` target is shown instead of letting the error bubble up, so
 * MaMpf is never affected if MampfSearch is down.
 */
export default class extends Controller {
  static targets = ["status", "content", "unavailable", "unavailableMessage",
    "form", "input"];

  static values = {
    url: String,
    connecting: { type: String, default: "connection…" },
    labels: { type: Object, default: {} },
  };

  connect() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return;
    if (!this.hasFormTarget || !this.hasInputTarget) return;

    this.abortController = null;
    this.isLoading = false;
    this.submitHandler = this.handleSubmit.bind(this);
    this.formTarget.addEventListener("submit", this.submitHandler);

    if (this.inputTarget.value.trim()) {
      this.load();
    }
  }

  disconnect() {
    this.abortController?.abort();
    if (this.submitHandler && this.hasFormTarget) {
      this.formTarget.removeEventListener("submit", this.submitHandler);
    }
  }

  handleSubmit(event) {
    event.preventDefault();
    event.stopPropagation();
    this.load();
  }

  async load() {
    if (this.isLoading) return;

    const url = this.buildUrl();
    if (!url) {
      this.clearContent();
      return;
    }

    this.isLoading = true;
    this.abortController?.abort();
    this.abortController = new AbortController();

    this.setConnecting();

    try {
      const response = await fetch(url, {
        headers: { accept: "application/json" },
        redirect: "manual",
        signal: this.abortController.signal,
      });

      if (!response.ok || response.redirected) {
        throw new Error(await errorMessage(response));
      }

      const body = await response.json();
      if (body?.error) {
        throw new Error(body.error);
      }

      const results = Array.isArray(body?.results) ? body.results : [];
      this.statusTarget.textContent = "";
      this.renderResults(results);
    }
    catch (error) {
      if (error.name === "AbortError") return;
      this.setUnavailable(error.message);
    }
    finally {
      this.isLoading = false;
    }
  }

  buildUrl() {
    const query = this.inputTarget.value.trim();
    if (!query) return "";

    const separator = this.urlValue.includes("?") ? "&" : "?";
    return `${this.urlValue}${separator}search=${encodeURIComponent(query)}`;
  }

  renderResults(results) {
    this.clearContent();

    const heading = document.createElement("h4");
    heading.className = "text-muted text-center mb-4";
    heading.textContent = this.labelsValue.heading.replace("%{query}", this.inputTarget.value.trim());
    this.contentTarget.appendChild(heading);

    if (results.length === 0) {
      const noResults = document.createElement("div");
      noResults.className = "alert alert-secondary mt-4 text-center";
      noResults.textContent = this.labelsValue.no_results;
      this.contentTarget.appendChild(noResults);
      return;
    }

    const list = document.createElement("div");
    list.className = "list-group shadow-sm mt-4";

    for (const result of results) {
      list.appendChild(this.buildResultItem(result));
    }

    this.contentTarget.appendChild(list);
  }

  buildResultItem(result) {
    const item = document.createElement("a");
    item.href = result.play_url;
    item.target = "_blank";
    item.className = "list-group-item list-group-item-action flex-column align-items-start p-4 search-result-item border-start-0 border-end-0 border-top-0 border-bottom";

    const header = document.createElement("div");
    header.className = "d-flex w-100 justify-content-between mb-2";

    const title = document.createElement("h5");
    title.className = "mb-1 text-primary d-flex align-items-center";
    title.textContent = result.media_title || this.labelsValue.unknown_medium;
    header.appendChild(title);

    const meta = document.createElement("small");
    meta.className = "text-muted";
    meta.textContent = this.labelsValue.relevance.replace("%{score}", result.score);
    header.appendChild(meta);

    item.appendChild(header);

    const body = document.createElement("p");
    body.className = "mb-2 text-secondary";
    body.style.fontSize = "0.95rem";
    body.style.lineHeight = "1.5";
    body.style.fontStyle = "italic";

    if (Array.isArray(result.highlights) && result.highlights.length > 0) {
      body.appendChild(document.createTextNode("\u201E"));
      renderHighlightSegments(body, result.highlights);
      body.appendChild(document.createTextNode("\u201C"));
    }

    item.appendChild(body);

    const footer = document.createElement("div");
    footer.className = "mt-2 text-end";
    const footerText = document.createElement("span");
    footerText.className = "text-primary fw-semibold";
    footerText.style.fontSize = "0.85rem";
    footerText.textContent = this.labelsValue.play_from.replace("%{time}", secondsToTime(result.start_time));
    footer.appendChild(footerText);
    item.appendChild(footer);

    return item;
  }

  setConnecting() {
    this.statusTarget.textContent = this.connectingValue;
    if (this.hasUnavailableTarget) {
      this.unavailableTarget.classList.add("d-none");
    }
  }

  setUnavailable(message) {
    this.statusTarget.textContent = "";
    if (this.hasUnavailableTarget) {
      if (this.hasUnavailableMessageTarget && message) {
        this.unavailableMessageTarget.textContent = message;
      }
      this.unavailableTarget.classList.remove("d-none");
    }
  }

  clearContent() {
    if (this.hasContentTarget) {
      this.contentTarget.replaceChildren();
    }
  }
}
