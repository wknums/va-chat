# VA Chat Widget - Integration Guide

This guide shows you how to integrate the VA Chat Widget into any website in just a few simple steps.

## Quick Start (3 Steps)

### Step 1: Copy Widget Files

Copy these three files to your website's directory:

```
va-chat-widget.css       # Widget styles
va-chat-widget.js        # Widget functionality
va-search-integration.js # Optional: Search integration
```

### Step 2: Add to HTML

Add these lines to your HTML pages:

**In the `<head>` section:**
```html
<!-- VA Chat Widget CSS -->
<link rel="stylesheet" href="va-chat-widget.css">
```

**Before the closing `</body>` tag:**
```html
<!-- VA Chat Widget JS -->
<script src="va-chat-widget.js"></script>
<script src="va-search-integration.js"></script> <!-- Optional -->
```

### Step 3: Configure API Endpoint (Optional)

By default, the widget connects to `http://localhost:8080`. To change this:

```html
<script>
    // Wait for widget to load
    document.addEventListener('DOMContentLoaded', () => {
        // Update API endpoint
        if (window.VAChatWidget) {
            window.VAChatWidget.apiBaseUrl = 'https://your-api-endpoint.com';
        }
    });
</script>
```

## Features

### Chat Mode
- Conversational AI assistant
- Context-aware responses
- Thread persistence
- Source citations

### Search Mode
- Intelligent search results
- Clickable result links
- Snippet previews
- Fast navigation

### User Interface
- **Draggable**: Click and drag the header to move
- **Resizable**: Drag corner handles to resize
- **Responsive**: Works on desktop and mobile
- **Auto-expand**: Search mode automatically widens the widget

## Search Integration (Optional)

The `va-search-integration.js` file automatically integrates with search forms on your page.

### Requirements

Your search form needs either:
- A class of `search` on the `<form>` element, OR
- An input with `name="search"` or class `search__input`

### Example Search Form

```html
<form class="search">
    <input type="text" class="search__input" name="search" placeholder="Search...">
    <button type="submit" class="search__button">Search</button>
</form>
```

When users submit this form:
1. Widget opens automatically
2. Switches to search mode
3. Executes the search query
4. Displays results

## Customization

### Change Widget Colors

Edit `va-chat-widget.css` and modify the CSS variables:

```css
:root {
    --va-primary: #001489;        /* Primary color */
    --va-primary-light: #1a2da1;  /* Hover color */
    --va-white: #ffffff;          /* Text on primary */
    --va-gray-light: #f5f5f5;     /* Background */
    --va-gray: #666666;           /* Secondary text */
    --va-border: #ddd;            /* Borders */
    --va-shadow: rgba(0, 20, 137, 0.15); /* Shadows */
    --va-error: #d32f2f;          /* Error messages */
}
```

### Change Widget Position

In `va-chat-widget.css`, modify:

```css
#va-chat-widget {
    position: fixed;
    bottom: 20px;  /* Distance from bottom */
    right: 20px;   /* Distance from right */
}
```

For left side placement:
```css
#va-chat-widget {
    position: fixed;
    bottom: 20px;
    left: 20px;    /* Place on left */
    right: auto;
}
```

### Programmatic Control

```javascript
// Open widget
window.VAChatWidget.open();

// Close widget
window.VAChatWidget.close();

// Trigger search
window.VAChatWidget.search("your query here");

// Change mode
window.VAChatWidget.setMode('chat');  // or 'search'
```

## Backend Requirements

The widget requires a backend API with the following endpoint:

### POST /api/chat

**Request:**
```json
{
    "message": "user question",
    "thread_id": "optional-thread-id",
    "mode": "chat"  // or "search"
}
```

**Response:**
```json
{
    "message": "assistant response",
    "thread_id": "thread-identifier",
    "mode": "chat",
    "citations": [
        {
            "title": "Source Title",
            "url": "https://example.com",
            "snippet": "relevant excerpt"
        }
    ],
    "search_results": [  // Only for search mode
        {
            "title": "Result Title",
            "url": "https://example.com/page",
            "snippet": "result description"
        }
    ]
}
```

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Troubleshooting

### Widget doesn't appear
1. Check browser console for errors (F12)
2. Verify files are loaded correctly
3. Check file paths in HTML

### Search integration not working
1. Verify search form has class `search`
2. Check console for integration logs
3. Ensure `va-search-integration.js` is loaded

### Backend connection fails
1. Check API endpoint URL
2. Verify CORS settings on backend
3. Check network tab in DevTools

### Widget caching issues
Hard refresh browser: `Ctrl + Shift + R` (Windows/Linux) or `Cmd + Shift + R` (Mac)

## Example Implementation

See the files in this directory for a complete example:
- `index.html` - Homepage with widget
- `services.html` - Services page
- `about.html` - About page
- `contact.html` - Contact page
- `faq.html` - FAQ page

## License

This widget is part of the VA Chat project. Customize and use freely in your projects.

## Support

For issues or questions:
1. Use the widget's chat mode to ask questions
2. Check the FAQ page
3. Review browser console logs for errors
