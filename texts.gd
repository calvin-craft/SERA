extends RefCounted

# ==============================================================================
#  SERA 문구 모음
# ==============================================================================
#  게임 화면에 나오는 글자는 전부 이 파일에 있습니다. 문구를 바꾸려면 이 파일만
#  고치면 됩니다.
#
#  고치는 법
#   · 따옴표 "..." 안의 글자만 바꾸세요. 따옴표, 쉼표, 대괄호 [ ], 중괄호 { },
#     := 왼쪽의 영문 이름은 그대로 둡니다.
#   · {숫자} {스테이지} 처럼 중괄호로 싸인 낱말은 게임이 값을 채워 넣는 자리입니다.
#     문장 안에서 자리를 옮기거나 빼도 되지만, 중괄호 안의 낱말은 바꾸지 마세요.
#   · 문장 안에서 줄을 바꾸려면 \n 을 씁니다.
#   · 스테이지 이름과 구간 이름에는 / 를 쓰지 마세요. 화면 왼쪽 위 표시가 / 로
#     이름을 나눕니다.
#   · 대괄호 안에 문장이 여러 개인 말풍선은 한 줄에 한 문장입니다. 첫 문장은
#     세라의 말이고, 그 아래 문장들은 키 그림 옆에 붙는 안내입니다. 문장 수는
#     그대로 두는 것이 안전합니다.
#   · 고친 뒤 Godot에서 F5로 실행하면 바로 반영됩니다. 따옴표를 빠뜨리면
#     Godot이 이 파일의 해당 줄을 빨갛게 표시합니다.
# ==============================================================================


# ------------------------------------------------------------------------------
#  1. 막과 스테이지
# ------------------------------------------------------------------------------
#  스테이지 이름은 여기 한 곳만 고치면 타이틀 카드, 시작 배너, 왼쪽 위 표시,
#  이어하기 표시, 앞 스테이지 클리어 화면의 "○○(으)로" 버튼에 모두 반영됩니다.
#  ("으로/로"는 이름의 받침을 보고 자동으로 붙습니다.)
#  세라의 대사나 다른 문장 속에 들어 있는 스테이지 이름은 따로 고쳐야 합니다.

# 막 이름. 시작 배너와 스테이지 연습 화면에 "ACT 2 · 하강"처럼 나옵니다.
const ACTS := ["진입", "하강", "방출"]

# 스테이지 하나에 한 묶음, 캠페인 순서대로.
#   name         스테이지 이름
#   card         스테이지 연습 카드의 한 줄 소개
#   sections     구간 이름 세 개 (왼쪽 위 표시, 체크포인트 이름)
#   clear_title  클리어 화면의 큰 제목 아래 문구
#   clear_note   그 아래 이야기 한 줄 (비워 두려면 "")
#   says         세라가 그 스테이지에서 하는 이야기 대사 (순서대로, 줄 수 유지)
const STAGES := [
	{
		"name": "주조소",
		"card": "철제 빔 흡수와 가드 전투",
		"sections": ["흡수 구역", "경비 통로", "용광로"],
		"clear_title": "주조소 돌파",
		"clear_note": "경비 구역 너머로 냉각탑의 수직 통로가 보인다.",
		"says": [],
	},
	{
		"name": "냉각탑",
		"card": "릴레이 조준과 승강기",
		"sections": ["승강기 입구", "상부 통로", "제어실"],
		"clear_title": "냉각탑 돌파",
		"clear_note": "제어실 아래, 동력로가 낮게 울리고 있다.",
		"says": [],
	},
	{
		"name": "동력로",
		"card": "노심 수호기 보스전",
		"sections": ["상부 코어", "하부 코어", "마지막 코어"],
		"clear_title": "동력로 정지",
		"clear_note": "동력로가 멈췄다. 그런데 바닥의 진동은 오히려 커진다.",
		"says": [],
	},
	{
		"name": "압연 라인",
		"card": "컨베이어 도약과 돌격 기체",
		"sections": ["이송 벨트", "프레스 열", "출하 벨트"],
		"clear_title": "압연 라인 돌파",
		"clear_note": "화물 통로 아래에서 뜨거운 김이 올라온다.",
		"says": [
			"동력로를 껐는데도 벨트가 돌아. 바퀴에 남은 힘이야.",          # 시작 직후
			"포어맨이 나를 설비 고장으로 분류했나 봐. 뭔가 굴러온다.",     # 프레스 열 입구
			"화물 통로는 이 벨트 건너편이야. 조금만 더.",                  # 출하 벨트 입구
		],
	},
	{
		"name": "증기 배관로",
		"card": "증기 돌파와 호버 드론",
		"sections": ["누출 구역", "정비 통로", "배출 수직구"],
		"clear_title": "증기 배관로 돌파",
		"clear_note": "배관 끝, 야적장 위로 거대한 크레인이 움직인다.",
		"says": [
			"냉각이 멈춰서 배관이 터지고 있어. 데지 않게 가자.",                 # 시작 직후
			"저 소리… 드론이야. 포어맨이 나를 찾고 있어.",                       # 정비 통로 입구
			"이 아래가 출하 야드야. 화물 승강기로 바퀴까지 내려갈 수 있어.",     # 배출 수직구 입구
		],
	},
	{
		"name": "출하 야드",
		"card": "갠트리 크레인 보스전",
		"sections": ["첫 번째 하역", "과적 경보", "야드 폭주"],
		"clear_title": "갠트리 정지",
		"clear_note": "화물 승강기가 열렸다. 아래에서 바퀴가 운다.",
		"says": [
			"화물 승강기는 저 크레인 아래야. 비켜 줄 것 같진 않네.",       # 보스가 깨어나기 전
		],
	},
	{
		"name": "외곽 링",
		"card": "고속 벨트와 왕복 발판",
		"sections": ["진입 램프", "관성 벨트", "저장고 문"],
		"clear_title": "외곽 링 돌파",
		"clear_note": "저장고 문 너머, 포어맨의 관제탑이 서 있다.",
		"says": [
			"여기부터 바퀴의 외곽 링이야. 벨트가 훨씬 빨라.",              # 시작 직후
			"바닥이 떨려. 베어링이 오래 못 버텨.",                         # 관성 벨트 입구
			"저 문 뒤가 저장고야. 차폐된 놈이 지키고 있어.",               # 저장고 문 입구
		],
	},
	{
		"name": "관제 중추",
		"card": "세 층을 오르는 종합 시험",
		"sections": ["하층 정비고", "중층 이송로", "상층 관제실"],
		"clear_title": "관제 중추 돌파",
		"clear_note": "관제실 바닥이 열린다. 그 아래에 대관성륜이 있다.",
		"says": [
			"포어맨의 관제탑이야. 세 층만 올라가면 돼.",                   # 시작 직후
			"…3년 전에도 여기까지 왔었어. 그땐 못 멈췄지.",                # 중층에 올라와서
			"이번엔 부수는 게 아니야. 받아서, 돌려주는 거야.",             # 상층에 올라와서
		],
	},
	{
		"name": "대관성륜",
		"card": "포어맨 최종전",
		"sections": ["차폐", "돌진", "관성 방출"],
		"clear_title": "대관성륜 정지",
		"clear_note": "바퀴가 멎는다. 받은 만큼, 하늘로 돌려보냈다.",
		"says": [
			"저게 포어맨. 그리고 저 뒤가… 바퀴야.",                        # 보스가 깨어나기 전
		],
	},
]

# 보스 이름. 보스 체력 표시와 왼쪽 위 표시에 나옵니다.
const BOSS_REACTOR := "노심 수호기"
const BOSS_GANTRY := "갠트리"
const BOSS_FOREMAN := "포어맨"


# ------------------------------------------------------------------------------
#  2. 타이틀 화면
# ------------------------------------------------------------------------------
const TITLE_CONTINUE := "이어하기"
const TITLE_NEW_GAME := "새 게임"
const TITLE_PRACTICE := "스테이지 연습"
const TITLE_QUIT := "종료"
# 이어하기 아래의 작은 글씨.
const TITLE_RESUME := "{스테이지}  ·  {구간}  ·  운동량 {운동량}"
const TITLE_NO_SAVE := "저장 없음"
const TITLE_SAVE_UNREADABLE := "저장 파일을 읽을 수 없습니다."
const TITLE_CANNOT_OPEN := "스테이지를 열 수 없습니다."
# 저장이 있는데 새 게임을 고르면 뜨는 확인 창. {스테이지}는 첫 스테이지 이름.
const CONFIRM_TITLE := "새 게임"
const CONFIRM_TEXT := "이어하기 위치를 {스테이지} 입구로 바꾸고\n새 게임을 시작할까요?"
const CONFIRM_OK := "새 게임 시작"
const CONFIRM_CANCEL := "취소"
# 화면 아래의 키 안내.
const KEY_SELECT := "선택"
const KEY_CONFIRM := "결정"
const KEY_PAUSE_IN_PLAY := "플레이 중 일시 정지"

# 스테이지 연습 화면.
const PRACTICE_EYEBROW := "STAGE SELECT"
const PRACTICE_HEADING := "스테이지 연습"
const PRACTICE_NOTE := "운동량 0에서 시작합니다. 클리어한 연습 기록은 다음 도전과 비교할 수 있습니다."
const PRACTICE_DELTA := "{차이}초"
const PRACTICE_KEY_STAGES := "스테이지 · 막 넘기기"
const PRACTICE_KEY_START := "시작"
const PRACTICE_BACK := "돌아가기"
# 카드.
const CARD_STAGE := "STAGE {번호}"
const CARD_CLEARED := "클리어"
const CARD_BEST := "캠페인 최고"
const CARD_RECORD := "캠페인 최고 기록 {기록}"
const CARD_PRACTICE_BEST := "연습 최고"
const CARD_PRACTICE_RECORD := "연습 최고 기록 {기록}"
# 막 표시. 시작 배너와 연습 화면에 나옵니다.
const ACT_LABEL := "ACT {막}  ·  {이름}"


# ------------------------------------------------------------------------------
#  3. 일시 정지 화면
# ------------------------------------------------------------------------------
const PAUSE_EYEBROW := "PAUSED"
const PAUSE_HEADING := "일시 정지"
const PAUSE_CONTINUE := "계속하기"
const PAUSE_RETRY := "체크포인트부터"
const PAUSE_TO_TITLE := "타이틀로"
const PAUSE_HELP := "타이틀에서 마지막 체크포인트로 이어갈 수 있습니다."
# 제목 아래의 진행 기록.
const PAUSE_DETAIL := "{시간}   ·   정밀 흡수 {정밀}   ·   재시도 {재시도}"
# 조작표. 위에서부터 A/D, Space, 좌클릭, Shift, W+Shift, 우클릭, W+우클릭, E, R 옆의 설명입니다.
const CONTROLS_EYEBROW := "CONTROLS"
const CONTROLS_HEADING := "조작"
const CONTROLS := [
	"이동",
	"점프",
	"길게 눌러 흡수",
	"대시 · 운동량 34",
	"에너지 도약 · 운동량 34",
	"충격파 · 운동량 50",
	"위로 충격파",
	"열린 출구로 들어가기",
	"스테이지 처음부터",
]


# ------------------------------------------------------------------------------
#  4. 플레이 화면 표시 (HUD)
# ------------------------------------------------------------------------------
# 왼쪽 위와 시작 배너의 스테이지 번호.
const HUD_STAGE := "STAGE {번호}"
const HUD_STAGE_UNLISTED := "STAGE"
const HUD_PRACTICE := "PRACTICE"
# 시작 배너에서 체크포인트부터 이어 시작할 때의 부제.
const HUD_FROM_CHECKPOINT := "체크포인트  ·  {구간}"
# 오른쪽 위 운동량 표시.
const HUD_MOMENTUM := "운동량"
const HUD_DASH := "대시"
const HUD_SHOCKWAVE := "충격파"
# 말풍선의 이름표.
const HUD_SPEAKER := "세라"
# 운동량이 모자란데 대시나 충격파를 눌렀을 때.
const HUD_NOT_ENOUGH := "힘이 모자라… 운동량이 {숫자} 필요해"
# 보스 체력 표시.
const HUD_BOSS := "BOSS"
const HUD_BOSS_DORMANT := "대기 중"
# 클리어 화면.
const CLEAR_HEADLINE := "STAGE CLEAR"
const CLEAR_TIME := "소요 시간"
const CLEAR_PERFECT := "정밀 흡수"
const CLEAR_RETRIES := "재시도"
const CLEAR_PRACTICE_SEGMENT := "구간 {번호}"
const CLEAR_PRACTICE_SPLIT := "{기록}  ({차이})"
const CLEAR_PRACTICE_PREVIOUS := "이전 최고 {기록}"
const CLEAR_NEW_RECORD := "최고 기록 갱신"
const CLEAR_REPLAY := "다시 플레이"
const CLEAR_TO_TITLE := "타이틀로"
const CLEAR_CONTINUE_KEY := "E"


# ------------------------------------------------------------------------------
#  5. 화면 가운데 알림 · 모든 스테이지 공통
# ------------------------------------------------------------------------------
const NOTE_CHECKPOINT := "체크포인트"
const NOTE_PRACTICE_SPLIT := "체크포인트  ·  구간 {구간}  {차이}"
const NOTE_SAVE_FAILED := "체크포인트 저장 실패"
const NOTE_RECORD_FAILED := "기록 저장 실패"
const NOTE_RESTART_CHECKPOINT := "체크포인트에서 재시작"
const NOTE_RESTART_ENTRANCE := "입구에서 재시작"
# 탄을 받았을 때. 뒤에 "+56"처럼 얻은 양이 붙습니다.
const NOTE_ABSORB := "운동량 흡수"
const NOTE_ABSORB_PRECISE := "정밀 흡수"
const NOTE_SWEEP_EVADED := "바닥 충격파 회피"
const NOTE_SUIT_DAMAGED := "슈트 손상"
const NOTE_SUIT_DOWN := "슈트 손상 · 복귀 중"
# 차폐된 가드나 보스에게 충격파가 튕겼을 때.
const NOTE_SHIELDED := "차폐 중 · 위쪽 릴레이를 맞히세요"
const NOTE_ARMOR_BROKEN := "장갑 파손"
const NOTE_EXIT_OPEN := "출구 개방"
# 보스의 코어를 하나 부쉈을 때.
const NOTE_CORE_DAMAGED := "코어 손상 · 체크포인트"


# ------------------------------------------------------------------------------
#  6. 목표 표식 · 여러 스테이지 공통
# ------------------------------------------------------------------------------
#  화면 안의 대상 위에 떠서 깜빡이는 작은 이름표입니다.
const MARK_EXIT := "출구"
const MARK_LEAP := "도약 지점"
const MARK_VALVE := "압력 밸브"
const MARK_LIFT := "승강기"
const MARK_LIFT_RELAY := "승강기 릴레이"
const MARK_SHIELD_RELAY := "차폐 릴레이"
const MARK_AIM := "조준 지점"
const MARK_OPEN_CORE := "열린 코어"
const MARK_BOSS_WAKE := "다가가면 전투 시작"


# ------------------------------------------------------------------------------
#  7. 세라의 말풍선 · 모든 스테이지 공통 조작 안내
# ------------------------------------------------------------------------------
#  각 안내는 플레이어가 그 조작을 한 번 해 보면 다시 나오지 않습니다.

# 스테이지 시작. 둘째 줄은 [A][D] 키 그림 뒤, 셋째 줄은 [Space] 뒤에 붙습니다.
const HINT_MOVE := ["좋아, 가 보자.", "로 나를 움직여 줘", "누르면 뛰어오를게"]
# 파란 탄이 날아올 때. [좌클릭]
const HINT_ABSORB_SHOT := ["탄이 날아와! 받아서 힘으로 바꿀게.", "탄 쪽을 보고 길게 눌러 줘"]
# 붉은 바닥 파동이 올 때. [Space]
const HINT_EVADE := ["붉은 파동이야, 맞으면 아파!", "닿기 직전에 뛰어넘을게"]
# 운동량이 차고 가드가 가까울 때. [우클릭]
const HINT_RELEASE := ["모은 힘을 저 가드에게 돌려주자.", "가드를 보고 눌러 줘"]
# 열린 출구 앞. [E]
const HINT_EXIT := ["문이 열렸어. 여기로 나가자.", "누르면 들어갈게"]


# ------------------------------------------------------------------------------
#  8. 스테이지 1 · 주조소
# ------------------------------------------------------------------------------
const FOUNDRY_NOTE_PASSAGE := "연결 통로 개방"
const FOUNDRY_NOTE_HEAVY_ARMOR := "중장갑 파손"
const FOUNDRY_MARK_ABSORB := "흡수 구역"
const FOUNDRY_MARK_RECHARGE := "운동량 보충"
const FOUNDRY_MARK_HIGH_DECK := "높은 발판으로"
const FOUNDRY_MARK_DASH := "수평 대시 지점"
# 첫 빔 아래. [좌클릭]
const FOUNDRY_HINT_BEAM := ["저 빔이 떨어지면 내가 받아낼게.", "노란 구역에서 길게 눌러 줘"]
# 운동량이 찬 뒤 첫 구덩이 앞. [D + Shift]
const FOUNDRY_HINT_DASH := ["발판 끝에서 오른쪽으로 대시하자.", "오른쪽을 보고 있으면 Shift만 눌러도 돼"]
# 주조소의 두 번째 구덩이 앞. [W + Shift]
const FOUNDRY_HINT_HIGH_LEAP := ["저 발판은 높아. 이번엔 위로 도약하자.", "표식에서 오른쪽을 보고 같이 눌러 줘"]
# 운동량이 모자란 채 두 번째 빔 근처. [좌클릭]
const FOUNDRY_HINT_RECHARGE := ["힘이 모자라. 저 빔을 한 번 더 받자.", "노란 구역에서 길게 눌러 줘"]


# ------------------------------------------------------------------------------
#  9. 스테이지 2 · 냉각탑
# ------------------------------------------------------------------------------
const TOWER_NOTE_LIFT_POWER := "승강기 전원 연결"
const TOWER_NOTE_SHIELD_CUT := "가드 차폐 해제"
const TOWER_NOTE_EXIT_OPEN := "냉각탑 출구 개방"
# 첫 압력 밸브 앞. [좌클릭]
const TOWER_HINT_VALVE := ["저 밸브가 압력탄을 쏴. 받아서 힘으로 쓰자.", "다가가서 밸브를 보고 길게 눌러 줘"]
# 승강기 릴레이. [W + 우클릭]
const TOWER_HINT_LIFT_RELAY := ["저 위 릴레이를 맞히면 승강기가 움직일 거야.", "주황 표식 위에서 같이 눌러 줘"]
# 전원이 들어온 승강기 앞.
const TOWER_HINT_LIFT := ["전원이 들어왔어. 승강기 가운데에 서 볼게."]
# 상부 통로의 도약 지점. [W + Shift]
const TOWER_HINT_LEAP := ["힘이 찼어! 저 위 발판으로 뛰어 볼게.", "발판 끝에서 같이 눌러 줘"]
# 차폐된 가드 앞. [W + 우클릭]
const TOWER_HINT_SHIELD := ["차폐 때문에 안 통해. 저 릴레이부터 끊자.", "조준 표식에서 같이 눌러 줘"]


# ------------------------------------------------------------------------------
#  10. 스테이지 3 · 동력로 (보스 노심 수호기)
# ------------------------------------------------------------------------------
const REACTOR_NOTE_WAKE := "노심 수호기 기동"
# 탄을 받아 코어가 열렸을 때. 뒤에 얻은 양이 붙습니다.
const REACTOR_NOTE_CORE_OPEN := "흡수 성공 · 코어 개방"
const REACTOR_NOTE_CORE_OPEN_PRECISE := "정밀 흡수 · 코어 개방"
const REACTOR_NOTE_CORE_SHUT := "코어 밀폐 · 파란 탄을 받아 여세요"
const REACTOR_NOTE_STOPPED := "동력로 정지"
const REACTOR_NOTE_PRESS_EVADED := "낙하 프레스 회피"
# 보스 체력 표시 오른쪽의 상태.
const REACTOR_STATUS_OPEN := "코어 노출"
const REACTOR_STATUS_SHUT := "코어 밀폐"
# 코어가 닫혀 있을 때. [좌클릭]
const REACTOR_HINT_OPEN_CORE := ["코어가 닫혀 있어. 파란 탄을 받으면 열릴 거야.", "수호기를 보고 길게 눌러 줘"]
# 위쪽 코어가 열렸을 때. [W + 우클릭]
const REACTOR_HINT_AIM_UP := ["열렸어! 위쪽 코어를 노릴게.", "주황 표식 위에서 같이 눌러 줘"]
# 아래쪽 코어가 열렸을 때. [우클릭]
const REACTOR_HINT_STRIKE := ["열렸어! 지금 날려 버리자.", "코어를 보고 눌러 줘"]


# ------------------------------------------------------------------------------
#  11. 스테이지 4 · 5 · 7 · 8 공통 (벨트, 프레스, 증기, 돌격 기체, 드론, 릴레이)
# ------------------------------------------------------------------------------
const SECTOR_NOTE_PASSAGE := "통로 개방"
const SECTOR_NOTE_STEAM_CUT := "증기 차단"
const SECTOR_NOTE_RAM_BROKEN := "돌격 기체 파괴"
# 기절하지 않은 돌격 기체에 충격파가 튕겼을 때.
const SECTOR_NOTE_RAM_ARMOR := "전면 장갑 · 돌진을 받아내 멈추세요"
# 돌진을 받아냈을 때. 뒤에 얻은 양이 붙습니다.
const SECTOR_NOTE_RAM_CAUGHT := "돌진 흡수 · 기체 정지"
const SECTOR_NOTE_RAM_CAUGHT_PRECISE := "정밀 흡수 · 돌진 정지"
const SECTOR_NOTE_DRONE_DOWN := "드론 격추"
const SECTOR_NOTE_RELAY := "릴레이 연결"
const SECTOR_NOTE_TIMED_RELAY := "시한 릴레이 작동 · 서두르세요"

# 돌격 기체가 조준하거나 돌진해 올 때. [좌클릭]
const SECTOR_HINT_RAM_CATCH := ["마주 보고 받아내자. 파란 불이 정밀 흡수 신호야.", "길게 누르면 흡수 · 파란 불에 맞춰 누르면 정밀 흡수"]
# 돌격 기체가 기절했을 때. [우클릭]
const SECTOR_HINT_RAM_BREAK := ["멈췄어! 받은 만큼 돌려주자.", "기체를 보고 눌러 줘"]
# 드론을 처음 봤고 운동량이 모자랄 때. [좌클릭]
const SECTOR_HINT_DRONE_SHOT := ["드론이야. 내려와서 쏘는 탄을 받아 두자.", "드론을 보고 길게 눌러 줘"]
# 운동량이 있고 드론이 내려와 있을 때. [우클릭]
const SECTOR_HINT_DRONE_LOW := ["내려왔어, 지금이야!", "드론을 보고 눌러 줘"]
# 운동량이 있고 드론이 떠 있을 때. [W + 우클릭]
const SECTOR_HINT_DRONE_HIGH := ["떠 있을 땐 대각선으로 쏴야 닿아.", "비스듬히 아래에서 같이 눌러 줘"]
# 프레스 앞.
const SECTOR_HINT_PRESS := ["프레스야. 내려찍은 직후에 지나가자."]
# 주기적으로 멎는 증기 앞.
const SECTOR_HINT_STEAM := ["증기가 멎는 틈에 지나가자."]
# 멎지 않는 증기 앞, 운동량이 있을 때. [Shift]
const SECTOR_HINT_STEAM_DASH := ["안 멎는 증기네. 대시 중엔 안 데어.", "증기를 보고 눌러 줘"]
# 멎지 않는 증기 앞, 운동량이 모자랄 때.
const SECTOR_HINT_STEAM_WAIT := ["뚫으려면 힘이 필요해. 먼저 탄을 받자."]
# 밀어 주는 벨트 위. [Space]
const SECTOR_HINT_BELT := ["벨트가 밀어 주네. 이 속도 그대로 뛰면 멀리 가.", "벨트 끝에서 눌러 줘"]
# 거꾸로 도는 벨트 위. [Space]
const SECTOR_HINT_BELT_BACK := ["거꾸로 도는 벨트야. 발이 닿으면 밀려.", "연달아 뛰어서 건너자"]
# 시한 릴레이 근처. [W + 우클릭]
const SECTOR_HINT_TIMED_RELAY := ["저 릴레이는 금방 꺼져. 맞히고 바로 달리자.", "바닥 표식 위에서 같이 눌러 줘"]

# 스테이지 4 · 압연 라인. 기절한 돌격 기체 위의 표식.
const MILL_MARK_STRIKE := "지금 충격파"
# 스테이지 7 · 외곽 링. 차폐된 가드 앞. [W + 우클릭]
const RING_HINT_SHIELD := ["차폐 때문에 안 통해. 저 릴레이부터 끊자.", "바닥 표식 위에서 같이 눌러 줘"]
# 스테이지 7 · 외곽 링. 증기 뒤의 정비 통로. [W + 우클릭]
const RING_MARK_MAINTENANCE := "정비 승강기 릴레이"
const RING_HINT_MAINTENANCE := ["이 승강기를 타면 벨트 위로 건너갈 수 있어.", "바닥 표식에서 위쪽 릴레이를 맞혀 줘"]
const RING_NOTE_MAINTENANCE := "정비 승강기 가동"
# 스테이지 8 · 관제 중추. 승강기 릴레이. [W + 우클릭]
const SPINE_HINT_LIFT_RELAY := ["저 릴레이가 승강기 전원이야.", "바닥 표식 위에서 같이 눌러 줘"]
# 스테이지 8 · 관제 중추. 마지막 방의 차폐된 가드. [W + 우클릭]
const SPINE_HINT_SHIELD := ["차폐부터 끊자. 드론은 그다음이야.", "바닥 표식 위에서 같이 눌러 줘"]


# ------------------------------------------------------------------------------
#  12. 스테이지 6 · 출하 야드 (보스 갠트리)
# ------------------------------------------------------------------------------
const YARD_NOTE_WAKE := "갠트리 기동"
# 강재를 받았을 때. 뒤에 얻은 양이 붙습니다.
const YARD_NOTE_CAUGHT := "강재 흡수 · 코어 노출"
const YARD_NOTE_SLAB_EVADED := "과적 슬래브 회피"
const YARD_NOTE_CORE_SHUT := "집게 잠김 · 파란 강재를 받아 여세요"
const YARD_NOTE_STOPPED := "갠트리 정지"
# 보스 체력 표시 오른쪽의 상태.
const YARD_STATUS_OPEN := "코어 노출"
const YARD_STATUS_SHUT := "집게 잠김"
# 빨간 불 슬래브가 떨어지려 할 때.
const YARD_HINT_DODGE := ["빨간 불은 너무 무거워. 받지 말고 밑에서 비켜!"]
# 파란 불 강재가 떨어지려 할 때. [좌클릭]
const YARD_HINT_CATCH := ["파란 불이 켜진 강재는 받을 수 있어.", "크레인 밑에서 길게 눌러 줘"]
# 코어가 드러났을 때. [W + 우클릭]
const YARD_HINT_CORE := ["집게가 비었어! 옆으로 나와서 대각선으로.", "바닥 표식 위에서 같이 눌러 줘"]


# ------------------------------------------------------------------------------
#  13. 스테이지 9 · 대관성륜 (최종 보스 포어맨)
# ------------------------------------------------------------------------------
const WHEEL_NOTE_WAKE := "포어맨 기동"
const WHEEL_NOTE_SHIELD_CUT := "차폐 해제 · 가슴 코어를 노리세요"
# 돌진을 받아냈을 때. 뒤에 얻은 양이 붙습니다.
const WHEEL_NOTE_CHARGE_CAUGHT := "돌진 흡수 · 포어맨 정지"
const WHEEL_NOTE_CHARGE_CAUGHT_PRECISE := "정밀 흡수 · 포어맨 정지"
# 바퀴에서 떨어진 화물을 받았을 때. 뒤에 얻은 양이 붙습니다.
const WHEEL_NOTE_LOAD_CAUGHT := "관성 흡수 · 코어 노출"
const WHEEL_NOTE_CORE_SHUT := "코어 밀폐"
# 마지막 장면.
const WHEEL_NOTE_FINALE := "대관성륜의 운동량이 슈트로 쏟아진다"
const WHEEL_NOTE_WRONG_WAY := "앞이 아니라 하늘로 · W를 누른 채 방출"
const WHEEL_NOTE_RELEASED := "방출 완료 · 대관성륜 정지"
# 보스 체력 표시 오른쪽의 상태.
const WHEEL_STATUS_SHIELDED := "차폐 중"
const WHEEL_STATUS_SHIELD_CUT := "차폐 해제"
const WHEEL_STATUS_CHARGING := "돌진"
const WHEEL_STATUS_STUNNED := "기절 · 코어 노출"
const WHEEL_STATUS_SHEDDING := "관성 방출"
const WHEEL_STATUS_OPEN := "코어 노출"
const WHEEL_STATUS_STOPPED := "정지"
# 1페이즈, 차폐가 켜져 있을 때. [W + 우클릭]
const WHEEL_HINT_SHIELD := ["또 차폐야. 릴레이부터 끊자.", "바닥 표식 위에서 같이 눌러 줘"]
# 1페이즈, 차폐가 꺼진 뒤. [우클릭]
const WHEEL_HINT_CORE := ["차폐가 꺼졌어. 가슴의 코어야!", "다가가서 코어를 보고 눌러 줘"]
# 2페이즈, 돌진해 올 때. [좌클릭]
const WHEEL_HINT_CATCH := ["돌진이야! 이건 못 넘어. 받아낸다.", "마주 보고 길게 눌러 줘"]
# 2페이즈, 기절했을 때. [우클릭]
const WHEEL_HINT_STUN := ["멈췄어! 지금이야.", "코어를 보고 눌러 줘"]
# 3페이즈, 빨간 불 화물.
const WHEEL_HINT_DODGE := ["바퀴가 쏟아내는 힘이야. 빨간 건 비켜!"]
# 3페이즈, 파란 불 화물. [좌클릭]
const WHEEL_HINT_LOAD := ["파란 건 받을 수 있어. 주조소에서처럼.", "떨어지는 자리에서 길게 눌러 줘"]
# 3페이즈, 코어가 드러났을 때. [W + 우클릭]
const WHEEL_HINT_PERCH_CORE := ["코어가 드러났어! 대각선으로.", "바닥 표식 위에서 같이 눌러 줘"]
# 마지막 장면. [W + 우클릭]
const WHEEL_HINT_FINALE := ["바퀴의 힘이 전부 나한테 왔어. 받은 만큼 돌려주자.", "하늘로, 같이 눌러 줘"]


# ==============================================================================
#  아래는 문구가 아니라 위의 문구를 꺼내 쓰는 코드입니다. 고칠 필요가 없습니다.
# ==============================================================================

const _BLANK := {"name": "", "card": "", "sections": ["", "", ""], "clear_title": "", "clear_note": "", "says": []}


## The text entry for the stage at `index`; a blank one for a scene outside the campaign.
static func stage(index: int) -> Dictionary:
	if index < 0 or index >= STAGES.size():
		return _BLANK
	return STAGES[index]


static func stage_name(index: int) -> String:
	return stage(index)["name"]


## The section name at `section`, or an empty string when the list is shorter.
static func section(index: int, part: int) -> String:
	var names: Array = stage(index)["sections"]
	return names[part] if part >= 0 and part < names.size() else ""


## The story line at `line` for the stage, or an empty string when it was removed.
static func say(index: int, line: int) -> String:
	var lines: Array = stage(index)["says"]
	return lines[line] if line >= 0 and line < lines.size() else ""


## "ACT 2  ·  하강" for the act the stage belongs to (three stages per act).
static func act_label(index: int) -> String:
	var act := clampi(floori(index / 3.0), 0, ACTS.size() - 1)
	return ACT_LABEL.format({"막": act + 1, "이름": ACTS[act]})


static func stage_number(index: int) -> String:
	return HUD_STAGE.format({"번호": "%02d" % (index + 1)})


## "냉각탑으로", "동력로로": the name with the particle that fits its last sound.
static func toward(name: String) -> String:
	if name.is_empty():
		return ""
	var code := name.unicode_at(name.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return name + "(으)로"
	var final_consonant := (code - 0xAC00) % 28
	return name + ("로" if final_consonant == 0 or final_consonant == 8 else "으로")
