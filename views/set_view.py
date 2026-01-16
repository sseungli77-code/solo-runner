import flet as ft

class SetView(ft.Column):
    def __init__(self):
        super().__init__()
        self.spacing = 20
        self.controls = [
            ft.Text("사용자 설정 (Settings)", size=24, weight=ft.FontWeight.BOLD),
            ft.TextField(label="키 (Height, cm)", keyboard_type=ft.KeyboardType.NUMBER),
            ft.TextField(label="몸무게 (Weight, kg)", keyboard_type=ft.KeyboardType.NUMBER),
            ft.Text("성별 (Gender)", size=16),
            ft.RadioGroup(content=ft.Row([
                ft.Radio(value="male", label="남성"),
                ft.Radio(value="female", label="여성"),
            ])),
            ft.ElevatedButton("정보 저장 (Save Info)", icon=ft.Icons.SAVE, on_click=self.save_info),
        ]

    def save_info(self, e):
        # Implementation for saving to client_storage can be added here
        print("Saving user info...")
        snack_bar = ft.SnackBar(ft.Text("정보가 저장되었습니다!"))
        # As SetView is a child, we need to access page via self.page which is available after it's added
        if self.page:
            self.page.snack_bar = snack_bar
            snack_bar.open = True
            self.page.update()
