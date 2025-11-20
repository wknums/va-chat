/**
 * VA Search Integration
 * Integrates native search forms with the AI-powered chat widget search
 */

(function() {
    'use strict';
    
    // Wait for DOM and chat widget to be ready
    function initializeSearchIntegration() {
        console.log('[VA Search Integration] Initializing...');
        console.log('[VA Search Integration] VAChat available:', typeof window.VAChat !== 'undefined');
        console.log('[VA Search Integration] VAChatWidget available:', typeof window.VAChatWidget !== 'undefined');
        
        // Find all search forms on the page
        const searchForms = document.querySelectorAll('form.search');
        
        if (searchForms.length === 0) {
            console.log('[VA Search Integration] No search forms found');
            return;
        }
        
        console.log(`[VA Search Integration] Found ${searchForms.length} search form(s), integrating with chat widget`);
        
        searchForms.forEach((form, index) => {
            // Prevent default form submission
            form.addEventListener('submit', function(e) {
                e.preventDefault();
                
                // Get the search input
                const searchInput = form.querySelector('input[name="search"], .search__input');
                if (!searchInput) {
                    console.warn('Search input not found in form', index);
                    return;
                }
                
                const query = searchInput.value.trim();
                if (!query) {
                    console.log('[VA Search Integration] Empty search query');
                    return;
                }
                
                console.log('[VA Search Integration] Search form submitted with query:', query);
                
                // Check if chat widget exists (try both names)
                const chatWidget = window.VAChat || window.VAChatWidget;
                if (!chatWidget) {
                    console.error('[VA Search Integration] VA Chat widget not loaded yet');
                    alert('Search functionality is loading. Please try again in a moment.');
                    return;
                }
                
                console.log('[VA Search Integration] Chat widget found:', chatWidget);
                
                // Open the chat widget
                if (typeof chatWidget.open === 'function') {
                    console.log('[VA Search Integration] Opening widget...');
                    chatWidget.open();
                } else {
                    console.warn('[VA Search Integration] open() function not available');
                }
                
                // Wait a brief moment for the widget to open, then trigger search
                setTimeout(() => {
                    if (typeof chatWidget.search === 'function') {
                        console.log('[VA Search Integration] Calling search() with query:', query);
                        chatWidget.search(query);
                        console.log('[VA Search Integration] Search triggered successfully');
                    } else {
                        console.error('[VA Search Integration] search() function not available, trying fallback');
                        
                        // Fallback: try to populate the input and trigger send
                        const chatInput = document.getElementById('va-chat-input');
                        const chatButton = document.getElementById('va-mode-chat');
                        const searchButton = document.getElementById('va-mode-search');
                        
                        if (chatInput && searchButton) {
                            console.log('[VA Search Integration] Using fallback method');
                            
                            // Click search mode button
                            searchButton.click();
                            
                            // Set the query
                            chatInput.value = query;
                            
                            // Trigger send button click
                            const sendBtn = document.getElementById('va-send-button');
                            if (sendBtn) {
                                sendBtn.click();
                                console.log('[VA Search Integration] Fallback: Populated input and clicked send');
                            } else {
                                console.error('[VA Search Integration] Send button not found');
                            }
                        } else {
                            console.error('[VA Search Integration] Fallback elements not found');
                        }
                    }
                }, 300);
                
                // Clear the search form input
                searchInput.value = '';
            });
        });
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            console.log('[VA Search Integration] DOM loaded, waiting for widget...');
            // Wait a bit for widget to initialize
            setTimeout(initializeSearchIntegration, 500);
        });
    } else {
        // DOM already loaded
        console.log('[VA Search Integration] DOM already loaded, waiting for widget...');
        setTimeout(initializeSearchIntegration, 500);
    }
    
    // Also try again after a longer delay to ensure widget is ready
    setTimeout(() => {
        console.log('[VA Search Integration] Re-initializing after delay...');
        initializeSearchIntegration();
    }, 2000);
    
})();

