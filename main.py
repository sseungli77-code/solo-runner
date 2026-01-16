import flet as ft
from views.run_view import RunView
from views.log_view import LogView
from views.set_view import SetView

def main(page: ft.Page):
    page.title = "SoloRunner"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 0
    page.window_width = 400
    page.window_height = 800

    # 뷰 인스턴스 바로 생성
    run_view = RunView()
    log_view = LogView()
    set_view = SetView()
    
    container = ft.Container(content=run_view, expand=True, padding=20)
    
    def on_nav_change(e):
        if e.control.selected_index == 0:
            container.content = run_view
        elif e.control.selected_index == 1:
            container.content = log_view
        else:
            container.content = set_view
        page.update()

    page.navigation_bar = ft.NavigationBar(
        selected_index=0,
        destinations=[
            ft.NavigationBarDestination(icon=ft.Icons.RUN_CIRCLE, label="Run"),
            ft.NavigationBarDestination(icon=ft.Icons.HISTORY, label="Log"),
            ft.NavigationBarDestination(icon=ft.Icons.SETTINGS, label="Set"),
        ],
        on_change=on_nav_change,
    )
    
    # 바로 메인 화면 추가
    page.add(container)
    page.update()

if __name__ == "__main__":
    # 포트 8080으로 변경
    ft.run(main, assets_dir="assets", view=ft.AppView.WEB_BROWSER, port=8081)
