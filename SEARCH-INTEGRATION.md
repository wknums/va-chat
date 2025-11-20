# Native Search Integration - Feature Documentation

## Overview
The Government Chat Widget now integrates seamlessly with the existing search forms on government website pages, providing a working search solution to replace the non-functional native search.

## What Was Implemented

### 1. Widget Public API (`frontend/va-chat-widget.js`)
Added three public methods to the widget class:

```javascript
// Open the chat widget
window.VAChat.open()

// Close the chat widget  
window.VAChat.close()

// Open widget in search mode with a query
window.VAChat.search("your search query")
```

### 2. Search Integration Script (`site/va-search-integration.js`)
A new standalone script that:
- Automatically detects all search forms on the page (`<form class="search">`)
- Intercepts form submissions (prevents default navigation)
- Opens the chat widget automatically
- Switches to search mode
- Passes the search query to the AI agent
- Clears the search input after submission

### 3. HTML Integration
Updated all relevant HTML pages to include the integration script:
- `site/index.html`
- `site/test-chat-widget.html`
- And can be added to any other page with search forms

## How It Works

### User Flow
1. User types "education programs" in the native search box at the top of the page
2. User clicks the search button or presses Enter
3. JavaScript intercepts the form submission
4. Chat widget opens in the bottom-right corner
5. Widget automatically switches to Search mode (🔍)
6. Query is sent to Azure AI Foundry agent with Bing Search grounding
7. Results appear in traditional search result format with:
   - Document icon (📄)
   - Title (blue, clickable)
   - URL (green, below title)
   - Hover effects for better UX

### Technical Flow
```
Search Form Submit
        ↓
va-search-integration.js intercepts
        ↓
window.VAChat.open()
        ↓
window.VAChat.search(query)
        ↓
Widget switches to search mode
        ↓
FastAPI POST /api/chat (mode: "search")
        ↓
Azure AI Foundry Agent + Bing Search
        ↓
Citation extraction from annotations
        ↓
Display results in widget
```

## Key Features

### Seamless Integration
- No page reloads required
- Works with existing HTML structure
- Non-intrusive (doesn't break existing page functionality)
- Progressive enhancement (works even if chat widget fails to load)

### Fallback Handling
The integration script includes multiple fallback strategies:
1. Try to use `window.VAChat.search()` method (preferred)
2. If not available, manually populate input and click send button
3. If widget not loaded, show alert to user

### Error Handling
- Checks for widget availability before attempting integration
- Console logging for debugging
- User feedback if widget is still loading
- Graceful degradation if API is unavailable

## Testing the Feature

### Setup
1. Start FastAPI backend:
   ```powershell
   cd backend
   ..\\.venv\Scripts\Activate.ps1
   python main.py
   ```

2. Start HTTP server:
   ```powershell
   python scripts\serve-site.py
   ```

### Test Scenarios

#### Test 1: Basic Search Integration
1. Open http://localhost:9000/Western%20Cape%20Government%20_%20For%20You.html
2. Locate search box in header (top right, next to menu)
3. Type: "Government education services"
4. Press Enter or click search button
5. **Expected**: Widget opens in search mode, displays results with URLs

#### Test 2: Multiple Search Forms
1. Same page as above has multiple search forms (header, mobile menu)
2. Try searching from different locations
3. **Expected**: All forms trigger the widget correctly

#### Test 3: Empty Search
1. Click search button without entering text
2. **Expected**: Nothing happens (validation prevents empty searches)

#### Test 4: Widget Already Open
1. Click chat bubble to open widget manually
2. Now use native search form
3. **Expected**: Widget stays open, switches to search mode, displays new results

#### Test 5: Rapid Searches
1. Search for "jobs"
2. Immediately use native search for "bursaries"
3. **Expected**: Both searches process correctly, no race conditions

## Files Modified/Created

### New Files
- `site/va-search-integration.js` (114 lines)
  - Main integration script
  - Auto-discovery of search forms
  - Event listeners and widget API calls

### Modified Files
- `frontend/va-chat-widget.js`
  - Added `open()` method (lines 333-341)
  - Added `close()` method (lines 343-351)
  - Added `search(query)` method (lines 353-370)
  - Exposed as `window.VAChat` (lines 379, 383)

- `site/index.html`
  - Added `<script src="wcg-search-integration.js"></script>`

- `site/test-chat-widget.html`
  - Added `<script src="va-search-integration.js"></script>` (line 129)

- `README.md`
  - Added "Native Search Integration" to features list
  - Added search integration section in features detail
  - Updated project structure to include new file
  - Added integration notes to HTML integration section

## Browser Compatibility
- **Modern Browsers**: Full support (Chrome, Edge, Firefox, Safari)
- **IE11**: Not supported (uses modern JavaScript features)
- **Mobile**: Fully responsive and functional

## Performance Considerations
- Script is lightweight (~4KB unminified)
- Minimal DOM queries (cached after initial discovery)
- Event delegation where possible
- No external dependencies

## Security
- Uses `rel="noopener noreferrer"` on all external links
- No eval() or unsafe code execution
- Validates input before processing
- HTTPS ready (works with secure endpoints)

## Accessibility
- Maintains ARIA labels from widget
- Keyboard navigation preserved
- Screen reader compatible
- Focus management when widget opens

## Future Enhancements
- [ ] Support for advanced search syntax (filters, operators)
- [ ] Search suggestions/autocomplete from widget
- [ ] Analytics integration (track search queries)
- [ ] Voice search integration
- [ ] Search history in widget
- [ ] "Did you mean?" suggestions for typos

## Troubleshooting

### Widget doesn't open when searching
- Check browser console for errors
- Verify `va-chat-widget.js` loads before `va-search-integration.js`
- Check that widget initializes: `console.log(window.VAChat)`

### Search results don't appear
- Check FastAPI backend is running (port 8080)
- Verify network tab shows successful API call
- Check agent ID is correct in `.env`

### Multiple widgets appear
- Ensure scripts are only included once in HTML
- Check for duplicate initialization code
- Clear browser cache and reload

### Search form still navigates to old URL
- Check JavaScript isn't being blocked
- Verify event listener is attached: check console logs
- Ensure script runs after DOM is ready

## Code References

### Widget API Usage Example
```javascript
// Open widget
window.VAChat.open();

// Search for something
window.VAChat.search("government services");

// Close widget
window.VAChat.close();
```

### Custom Integration Example
```javascript
// Custom button triggering search
document.getElementById('my-search-btn').addEventListener('click', () => {
    const query = document.getElementById('my-input').value;
    if (query.trim()) {
        window.VAChat.search(query);
    }
});
```

## Support
For issues or questions, check:
1. Browser console for JavaScript errors
2. Network tab for API call status
3. FastAPI logs for backend errors
4. README.md troubleshooting section

