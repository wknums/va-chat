# SampleSite - VA Chat Widget Demo

A complete demo website showcasing the VA (Virtual Assistant) Chat Widget integration.

## 🌟 What is This?

This is a fully functional sample website that demonstrates how to integrate an AI-powered chat widget into any website. The widget provides:

- **💬 Chat Mode**: Conversational AI assistant for answering questions
- **🔍 Search Mode**: Intelligent search functionality across your website
- **📱 Responsive Design**: Works on desktop and mobile devices
- **🎨 Customizable**: Easy to customize colors, position, and behavior
- **🔗 Search Integration**: Automatically integrates with existing search forms

## 📁 What's Included

```
sample-site/
├── index.html                  # Homepage
├── services.html               # Services page
├── about.html                  # About page
├── contact.html                # Contact page
├── faq.html                    # FAQ page
├── va-chat-widget.css          # Widget styles
├── va-chat-widget.js           # Widget functionality
├── va-search-integration.js    # Search form integration
├── integrate-widget.ps1        # PowerShell integration script
├── integrate-widget.sh         # Bash integration script
├── INTEGRATION-GUIDE.md        # Detailed integration guide
└── README.md                   # This file
```

## 🚀 Quick Start

### View the Demo

1. Open `index.html` in your web browser
2. Click the chat button (💬) in the bottom-right corner
3. Try both Chat and Search modes
4. Test the search bar at the top of the page

### Features to Try

- **Resize**: Drag the blue circles at the corners to resize the widget
- **Move**: Click and drag the header to reposition the widget
- **Search**: Use the search bar to automatically trigger search mode
- **Navigate**: Click links on different pages - the widget stays persistent

## 🔧 Integration into Your Website

### Method 1: Use the Integration Script (Recommended)

**PowerShell (Windows):**
```powershell
.\integrate-widget.ps1 -WebsiteDir "C:\path\to\your\website"
```

**Bash (Linux/Mac):**
```bash
chmod +x integrate-widget.sh
./integrate-widget.sh /path/to/your/website
```

### Method 2: Manual Integration

**Step 1:** Copy these files to your website:
- `va-chat-widget.css`
- `va-chat-widget.js`
- `va-search-integration.js` (optional)

**Step 2:** Add to your HTML `<head>`:
```html
<link rel="stylesheet" href="va-chat-widget.css">
```

**Step 3:** Add before closing `</body>`:
```html
<script src="va-chat-widget.js"></script>
<script src="va-search-integration.js"></script>
```

**That's it!** The widget will automatically appear on your page.

## 📚 Detailed Documentation

See **[INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md)** for:
- Customization options
- API configuration
- Search integration setup
- Troubleshooting
- Programmatic control

## 🎨 Customization

### Change Colors

Edit the CSS variables in `va-chat-widget.css`:

```css
:root {
    --va-primary: #001489;        /* Your brand color */
    --va-primary-light: #1a2da1;  /* Lighter shade */
}
```

### Change Position

In `va-chat-widget.css`:

```css
#va-chat-widget {
    bottom: 20px;  /* Distance from bottom */
    right: 20px;   /* Distance from right */
}
```

### Configure API Endpoint

By default, the widget connects to `http://localhost:8080`. Change this in your HTML:

```html
<script>
    window.VAChatWidget.apiBaseUrl = 'https://your-api.com';
</script>
```

## 🔌 Backend Requirements

The widget requires a backend API endpoint:

**POST /api/chat**

Request:
```json
{
    "message": "user question",
    "thread_id": "optional",
    "mode": "chat" // or "search"
}
```

Response:
```json
{
    "message": "response text",
    "thread_id": "thread-id",
    "mode": "chat",
    "citations": [...],
    "search_results": [...]
}
```

See the main project's `backend/main.py` for a complete implementation using Azure AI Foundry.

## 🌐 Browser Support

- ✅ Chrome/Edge (latest)
- ✅ Firefox (latest)
- ✅ Safari (latest)
- ✅ Mobile browsers

## 💡 Use Cases

This widget is perfect for:

- **Customer Support**: Answer common questions automatically
- **Documentation Sites**: Help users find information quickly
- **E-commerce**: Assist customers with product questions
- **Internal Tools**: Provide contextual help to employees
- **Educational Sites**: Guide students to resources

## 🎯 Widget Features

### Chat Mode
- Context-aware conversations
- Thread persistence (remembers conversation)
- Source citations with links
- Markdown support

### Search Mode
- Full-text search across content
- Ranked results
- Clickable links
- Result snippets

### UI Features
- Draggable window
- Resizable from corners
- Minimize/expand
- Clear conversation
- Responsive design

## 📝 Publishing to GitHub

This sample site is designed to be non-customer-specific and can be safely published to GitHub as a demo/example.

**Recommended .gitignore additions:**
```
# Ignore customer-specific files
site/
!sample-site/

# Ignore environment files
.env
*.tfvars
!*.tfvars.example
```

## 🆘 Troubleshooting

**Widget doesn't appear?**
- Check browser console (F12) for errors
- Verify file paths in HTML are correct
- Hard refresh browser (Ctrl+Shift+R)

**Search integration not working?**
- Ensure search form has class `search`
- Check `va-search-integration.js` is loaded
- Review console logs

**Backend connection fails?**
- Verify API endpoint URL is correct
- Check CORS settings on backend
- Review network tab in DevTools

## 📄 License

This is a demo/example project. Feel free to use, modify, and distribute as needed.

## 🤝 Contributing

This is a sample implementation. For the main project or to report issues, see the parent repository.

## 📞 Support

For questions about integration:
1. Read the [INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md)
2. Check browser console for errors
3. Try the widget's chat mode for help!

---

**Happy Integrating! 🚀**
