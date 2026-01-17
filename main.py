import flet as ft

def main(page: ft.Page):
    # Setup page for immersive WebView experience
    page.title = "SoloRunner"
    page.padding = 0
    page.bgcolor = ft.colors.BLACK
    
    # Error handling for network issues
    def on_web_error(e):
        print(f"Web Error: {e.description}")
        page.snack_bar = ft.SnackBar(ft.Text(f"Connection Error: {e.description}"), bgcolor=ft.colors.RED_900)
        page.snack_bar.open = True
        page.update()

    # Hybrid WebView connecting to the cloud-hosted Web App
    # This solves GPS/Permissions issues by leveraging the browser engine within the app
    webview = ft.WebView(
        url="https://solo-runner.onrender.com",
        expand=True,
        on_web_resource_error=on_web_error
    )
    
    page.add(webview)

if __name__ == "__main__":
    # APK Entry Point
    ft.app(target=main)
