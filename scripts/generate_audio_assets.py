from gtts import gTTS
import os

def generate_audio():
    audio_dir = "assets/audio"
    if not os.path.exists(audio_dir):
        os.makedirs(audio_dir)
        print(f"Created directory: {audio_dir}")

    # (Key, Text)
    cues = {
        "start": "운동을 시작합니다. 즐거운 러닝 되세요!",
        "finish": "목표 달성! 오늘 운동을 종료합니다. 정말 고생하셨습니다.",
        "halfway": "절반 지점을 통과했습니다. 현재 페이스 양호합니다!",
        "last_1km": "마지막 1킬로미터입니다. 조금만 더 힘내세요!",
        "faster": "페이스가 조금 느립니다. 속도를 조금만 높여주세요.",
        "slower": "너무 빠릅니다! 호흡을 가다듬고 속도를 조금만 낮춰보세요.",
        "good_pace": "아주 좋습니다. 지금 페이스를 유지하세요!",
        "warning_fatigue": "피로도가 높게 감지됩니다. 무리하지 말고 천천히 뛰거나 걸어주세요."
    }

    print("Generating audio files...")
    for key, text in cues.items():
        file_path = os.path.join(audio_dir, f"{key}.mp3")
        print(f"Generating {file_path} for: '{text}'")
        tts = gTTS(text=text, lang='ko')
        tts.save(file_path)

    print("Successfully generated all audio files!")

if __name__ == "__main__":
    generate_audio()
