import flet as ft

class LogView(ft.Column):
    def __init__(self):
        super().__init__()
        self.controls = [
            ft.Text("러닝 기록 (Log)", size=24, weight=ft.FontWeight.BOLD),
            ft.Container(
                content=ft.DataTable(
                    columns=[
                        ft.DataColumn(ft.Text("Date")),
                        ft.DataColumn(ft.Text("Type")),
                        ft.DataColumn(ft.Text("Duration")),
                    ],
                    rows=[
                        ft.DataRow(cells=[ft.DataCell(ft.Text("2024-01-15")), ft.DataCell(ft.Text("Recovery")), ft.DataCell(ft.Text("30:00"))]),
                        ft.DataRow(cells=[ft.DataCell(ft.Text("2024-01-13")), ft.DataCell(ft.Text("Interval")), ft.DataCell(ft.Text("45:00"))]),
                    ]
                ),
                margin=ft.margin.only(top=20)
            ),
            ft.Container(
                height=200,
                content=ft.Text("Chart Placeholder", color=ft.colors.GREY),
                alignment=ft.Alignment(0, 0),
                border=ft.border.all(1, ft.colors.GREY),
                border_radius=10,
                margin=ft.margin.only(top=20)
            )
        ]
