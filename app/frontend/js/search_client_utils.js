/**
 * Shared helpers for the MampfSearch-driven search UIs (the lecture content
 * search and the thyme player search popup).
 */

export function renderHighlightSegments(container, segments) {
  for (const segment of Array.isArray(segments) ? segments : []) {
    const span = document.createElement("span");
    span.textContent = segment?.text || "";
    if (segment?.color) {
      span.style.backgroundColor = segment.color;
    }
    container.appendChild(span);
  }
}

export async function errorMessage(response) {
  try {
    const body = await response.json();
    return body?.error || `${response.status} ${response.statusText}`;
  }
  catch {
    return `${response.status} ${response.statusText}`;
  }
}
