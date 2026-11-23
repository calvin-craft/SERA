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
#   · 따옴표 안을 비우면("") 그 문구는 화면에 나오지 않습니다. 비워 둔 설명문은
#     다시 써 넣으면 그 자리에 나옵니다.
#   · 스테이지 이름과 구간 이름에는 / 를 쓰지 마세요. 화면 왼쪽 위 표시가 / 로
#     이름을 나눕니다.
#   · 대괄호 안에 문장이 여러 개인 말풍선은 한 줄에 한 문장입니다. 첫 문장은
#     세라의 말이고, 그 아래 문장들은 키 그림 옆에 붙는 안내입니다. 문장 수는
#     그대로 두는 것이 안전합니다.
#   · 고친 뒤 Godot에서 F5로 실행하면 바로 반영됩니다. 따옴표를 빠뜨리면
#     Godot이 이 파일의 해당 줄을 빨갛게 표시합니다.
# ==============================================================================


# ------------------------------------------------------------------------------
#  1. 챕터, 막과 스테이지
# ------------------------------------------------------------------------------
#  스테이지 이름은 여기 한 곳만 고치면 타이틀 카드, 시작 배너, 왼쪽 위 표시,
#  이어하기 표시, 앞 스테이지 클리어 화면의 "○○(으)로" 버튼에 모두 반영됩니다.
#  ("으로/로"는 이름의 받침을 보고 자동으로 붙습니다.)
#  세라의 대사나 다른 문장 속에 들어 있는 스테이지 이름은 따로 고쳐야 합니다.

# 챕터 하나에 한 묶음, 캠페인 순서대로.
#   name   챕터 이름. 챕터 시작 카드, 시작 배너, 타이틀의 새 게임 버튼,
#          스테이지 연습 화면, 챕터 클리어 화면에 나옵니다.
#   acts   그 챕터의 막 이름. 시작 배너와 스테이지 연습 화면에
#          "ACT 2 · 하강"처럼 나옵니다. 막 하나에 아래 STAGES의 스테이지가
#          세 개씩 순서대로 들어가므로, 막이 셋이면 스테이지 아홉 개입니다.
const CHAPTERS := [
	{
		"name": "포어맨",
		"acts": ["진입", "하강", "방출"],
	},
	{
		"name": "디스패처",
		"acts": ["추격", "부두", "출항"],
	},
	{
		"name": "에코",
		"acts": ["항해", "플랫폼", "반향"],
	},
]

# 스테이지 하나에 한 묶음, 캠페인 순서대로. 1챕터의 아홉 스테이지가 먼저 오고,
# 다음 챕터의 스테이지는 그 뒤에 이어 붙입니다.
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
	# ---- 2챕터 · 디스패처 ----
	{
		"name": "해안 선로",
		"card": "열차 다리와 포대",
		"sections": ["화물 선로", "신호소", "분기 선로"],
		"clear_title": "해안 선로 돌파",
		"clear_note": "선로 끝에서 바다 냄새가 난다.",
		"says": [
			"바퀴는 멎었는데 화물 열차는 아직 나가. 실을 게 남았다는 거야.",  # 시작 직후
			"신호소가 살아 있어. 누가 이 선로를 아직 굴리고 있어.",            # 신호소 입구
			"열차 무전이 잡혀. '디스패처 지시, 출항 일정 유지.'",              # 분기 선로 입구
		],
	},
	{
		"name": "절벽 철교",
		"card": "돌풍과 공중 흡수",
		"sections": ["강풍 구간", "교각", "철교 끝"],
		"clear_title": "절벽 철교 돌파",
		"clear_note": "철교 아래로 조차장의 불빛이 보인다.",
		"says": [
			"슈트가 공중 자세를 잡았어. 이제 뛰면서도 받을 수 있어.",          # 시작 직후
			"포어맨도 결국 누군가의 지시를 받고 있었던 거야.",                  # 교각 입구
			"다리 끝에 장갑 열차가 서 있어. 길을 막을 생각이야.",              # 철교 끝 입구
		],
	},
	{
		"name": "장갑 열차",
		"card": "장갑 열차 보스전",
		"sections": ["첫 포격", "선로 전진", "연속 포격"],
		"clear_title": "장갑 열차 정지",
		"clear_note": "장갑 열차가 멈췄다. 조차장 문이 열린다.",
		"says": [
			"저 장갑 열차가 항구로 가는 마지막 문이야.",                      # 보스가 깨어나기 전
		],
	},
	{
		"name": "조차장",
		"card": "아래로 방출과 해치",
		"sections": ["컨테이너 벽", "해치 구역", "적재 선로"],
		"clear_title": "조차장 돌파",
		"clear_note": "컨테이너마다 같은 행선지가 찍혀 있다. 켈더 해상 기지.",
		"says": [
			"보조 관제가 방출 제한을 풀었어. 이제 발밑으로도 쏠 수 있어.",    # 시작 직후
			"조차장 바닥이 해치투성이야. 아래로도 길이 나 있어.",              # 해치 구역 입구
			"컨테이너마다 같은 행선지가 찍혀 있어. 켈더 해상 기지.",            # 적재 선로 입구
		],
	},
	{
		"name": "컨테이너 부두",
		"card": "방패 경비",
		"sections": ["하역장", "방패 경비", "선적 부두"],
		"clear_title": "컨테이너 부두 돌파",
		"clear_note": "부두 끝에서 거대한 캐리어가 마지막 화물을 들어 올린다.",
		"says": [
			"부두에 화물선이 한 척 대 있어. 저기에 싣고 있는 거야.",            # 시작 직후
			"경비들이 방패를 들었어. 디스패처가 나를 알아본 거야.",            # 방패 경비 입구
			"화물선은 해상 기지로 간대. 3년 전, 그 실험이 있던 곳이야.",        # 선적 부두 입구
		],
	},
	{
		"name": "스트래들 캐리어",
		"card": "캐리어 보스전",
		"sections": ["첫 하역", "과적", "폭주"],
		"clear_title": "캐리어 정지",
		"clear_note": "캐리어가 쓰러졌다. 화물선은 이미 짐을 다 실었다.",
		"says": [
			"저 캐리어가 마지막 화물을 들고 있어.",                            # 보스가 깨어나기 전
		],
	},
	{
		"name": "방파제",
		"card": "투하기와 파도",
		"sections": ["파도 구간", "투하 구역", "등대"],
		"clear_title": "방파제 돌파",
		"clear_note": "방파제 끝, 관제탑의 불빛이 깜빡인다.",
		"says": [
			"방파제 끝에 관제탑이 있어. 디스패처는 거기 있어.",                # 시작 직후
			"머리 위로 투하기가 떠. 파란 통은 받을 수 있어.",                  # 투하 구역 입구
			"화물선이 시동을 걸었어. 서둘러야 해.",                            # 등대 입구
		],
	},
	{
		"name": "항만 관제탑",
		"card": "관제탑을 오르는 종합 시험",
		"sections": ["하층 화물칸", "중층 신호실", "관제실"],
		"clear_title": "항만 관제탑 돌파",
		"clear_note": "관제실 문이 열린다. 안에서 무언가가 출항을 지시하고 있다.",
		"says": [
			"관제탑이야. 꼭대기까지 올라가야 해.",                            # 시작 직후
			"디스패처의 기록… 3년 전 사고 보고서에 내 이름이 있어.",            # 중층에 올라와서
			"관제실이야. 배가 떠나기 전에 멈춰야 해.",                        # 상층에 올라와서
		],
	},
	{
		"name": "디스패처",
		"card": "디스패처 최종전",
		"sections": ["신호", "배차", "출항"],
		"clear_title": "디스패처 정지",
		"clear_note": "디스패처가 꺼졌다. 그러나 화물선은 이미 수평선 너머로 사라졌다.",
		"says": [
			"디스패처. 네가 이 모든 걸 실어 보냈구나.",                        # 보스가 깨어나기 전
		],
	},
	# ---- 3챕터 · 에코 ----
	{
		"name": "화물선 갑판",
		"card": "기우는 갑판과 반사",
		"sections": ["선미 갑판", "중앙 갑판", "선수 갑판"],
		"clear_title": "화물선 갑판 돌파",
		"clear_note": "선수 해치 아래로 선창의 불빛이 새어 나온다.",
		"says": [
			"화물선을 따라잡았어. 켈더 해상 기지까지 반나절이야.",              # 시작 직후
			"보조 관제가 또 슈트를 고쳐 놨어. 누가 나를 이렇게까지 돕는 거지?",  # 중앙 갑판 입구
			"선수 쪽 해치로 선창에 내려갈 수 있어.",                            # 선수 갑판 입구
		],
	},
	{
		"name": "선창",
		"card": "거울 포대와 반사 표적",
		"sections": ["화물칸", "냉동 구역", "선창 승강구"],
		"clear_title": "선창 돌파",
		"clear_note": "승강구 위에서 함교가 배를 몰고 있다.",
		"says": [
			"컨테이너가 떨려. 바퀴와 항구에서 모은 운동량이 이 안에 있어.",      # 시작 직후
			"켈더는 이 힘으로 뭘 하려는 거야…",                                # 냉동 구역 입구
			"함교로 올라가자. 이 배를 모는 놈이 있어.",                          # 선창 승강구 입구
		],
	},
	{
		"name": "키잡이",
		"card": "키잡이 보스전",
		"sections": ["거울 함교", "높은 창", "폭풍"],
		"clear_title": "키잡이 정지",
		"clear_note": "키를 잃은 화물선이 켈더 플랫폼에 부딪히며 멈춘다.",
		"says": [
			"저 함교가 배를 몰고 있어. 거울 뒤에 숨어서.",                      # 보스가 깨어나기 전
		],
	},
	{
		"name": "계류 데크",
		"card": "추적탄 발사기",
		"sections": ["접안 부두", "크레인 아래", "승강 사다리"],
		"clear_title": "계류 데크 돌파",
		"clear_note": "플랫폼 위층에서 낯익은 호출 부호가 울린다.",
		"says": [
			"켈더 해상 기지. 3년 전 그날 이후 처음이야.",                       # 시작 직후
			"기지가 깨어 있어. 누군가 이 화물을 기다리고 있었어.",               # 크레인 아래 입구
			"이 호출 부호… 에코야. 그럴 리가 없어.",                            # 승강 사다리 입구
		],
	},
	{
		"name": "파이프 랙",
		"card": "흡수 경비",
		"sections": ["배관 통로", "흡수 구역", "플레어 탑"],
		"clear_title": "파이프 랙 돌파",
		"clear_note": "플레어 탑 너머에서 시추 리그가 일어선다.",
		"says": [
			"배관마다 운동량이 흘러. 전부 실험동으로 모이고 있어.",              # 시작 직후
			"저 경비들, 내 충격파를 먹어. 에코의 슈트와 같은 방식이야.",         # 흡수 구역 입구
			"사고 기록의 생존자는 한 명이었어. 나 말이야.",                     # 플레어 탑 입구
		],
	},
	{
		"name": "시추 리그",
		"card": "시추 리그 보스전",
		"sections": ["추적", "흡수", "굴착"],
		"clear_title": "시추 리그 정지",
		"clear_note": "리그가 쓰러지며 실험동으로 가는 다리가 내려온다.",
		"says": [
			"저 리그가 실험동으로 가는 길을 막고 있어.",                       # 보스가 깨어나기 전
		],
	},
	{
		"name": "중력 시험동",
		"card": "저중력 실험실",
		"sections": ["감압실", "저중력 통로", "격리문"],
		"clear_title": "중력 시험동 돌파",
		"clear_note": "격리문 너머에서 누군가 내 이름을 부른다.",
		"says": [
			"실험동이야. 중력 장치가 아직 돌아가고 있어.",                      # 시작 직후
			"여기서 슈트를 시험했었어. 에코랑 나, 둘이서.",                     # 저중력 통로 입구
			"격리문 너머에서 신호가 와. 에코야. 살아 있었어.",                  # 격리문 입구
		],
	},
	{
		"name": "반향실",
		"card": "실험동을 오르는 종합 시험",
		"sections": ["하층 시험장", "중층 관측실", "상층 제어실"],
		"clear_title": "반향실 돌파",
		"clear_note": "제어실 문이 열린다. 에코가 기다리고 있다.",
		"says": [
			"에코가 화물을 모으고 있었어. 바퀴와 항구의 힘 전부를.",            # 시작 직후
			"사고 보고서… 그날 실험을 멈춘 건 나였어. 에코를 두고.",            # 중층에 올라와서
			"이번엔 두고 가지 않아.",                                          # 상층에 올라와서
		],
	},
	{
		"name": "에코",
		"card": "에코 최종전",
		"sections": ["반사", "추격", "반향"],
		"clear_title": "에코 정지",
		"clear_note": "에코의 슈트가 멈췄다. 모아 둔 힘이 바다로 흩어진다.",
		"says": [
			"에코. 3년 만이야.",                                               # 보스가 깨어나기 전
		],
	},
]

# 보스 이름. 보스 체력 표시와 왼쪽 위 표시에 나옵니다.
const BOSS_REACTOR := "노심 수호기"
const BOSS_GANTRY := "갠트리"
const BOSS_FOREMAN := "포어맨"
const BOSS_TRAIN := "장갑 열차"
const BOSS_CARRIER := "스트래들 캐리어"
const BOSS_DISPATCHER := "디스패처"
const BOSS_HELMSMAN := "키잡이"
const BOSS_RIG := "시추 리그"
const BOSS_ECHO := "에코"


# ------------------------------------------------------------------------------
#  2. 타이틀 화면
# ------------------------------------------------------------------------------
const TITLE_CONTINUE := "이어하기"
const TITLE_NEW_GAME := "새 게임"
const TITLE_PRACTICE := "스테이지 연습"
const TITLE_QUIT := "종료"
# 이어하기 아래의 작은 글씨. {챕터}를 넣으면 챕터 이름이 나옵니다.
const TITLE_RESUME := "{스테이지}  ·  {구간}  ·  운동량 {운동량}"
# 새 게임 아래의 작은 글씨는 챕터 표시(CHAPTER_LABEL)입니다.
const TITLE_NO_SAVE := "저장 없음"
const TITLE_SAVE_UNREADABLE := "저장 파일을 읽을 수 없습니다."
const TITLE_CANNOT_OPEN := "스테이지를 열 수 없습니다."
# 저장이 있는데 새 게임을 고르면 뜨는 확인 창. {스테이지}는 첫 스테이지 이름,
# {챕터}는 첫 챕터 이름.
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
const PRACTICE_NOTE := ""
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
# 챕터 표시. 시작 배너, 새 게임 버튼, 연습 화면, 챕터 클리어 화면에 나옵니다.
const CHAPTER_LABEL := "CHAPTER {번호}  ·  {이름}"
# 챕터 시작 카드의 윗줄. 아랫줄에는 챕터 이름이 크게 나옵니다.
# 새 게임처럼 캠페인에서 챕터 첫 스테이지에 들어갈 때 한 번 뜹니다.
const CHAPTER_CARD := "CHAPTER {번호}"
# 막 표시. 시작 배너와 연습 화면에 나옵니다.
const ACT_LABEL := "ACT {막}  ·  {이름}"
# 아직 캠페인에서 들어가 보지 않은 스테이지의 카드. 1챕터는 처음부터 열려 있습니다.
const CARD_LOCKED := "잠김"
const CARD_LOCKED_NOTE := ""
# 연습 화면 아래 키 안내. 위 방향키로 챕터 탭에 올라가 챕터를 바꿉니다.
const PRACTICE_KEY_CHAPTERS := "챕터 바꾸기"

# 챕터 선택. 새 게임을 누르면 뜨고, 오른쪽에 고른 챕터의 보스가 나옵니다.
# 깬 챕터의 다음 챕터까지 고를 수 있고, 그 뒤 챕터는 잠김(보스는 실루엣)입니다.
# HEADING은 큰 제목, NOTE는 그 아래 설명입니다. 비워 두면 나오지 않습니다.
const CHAPTER_SELECT_EYEBROW := "NEW GAME"
const CHAPTER_SELECT_HEADING := ""
const CHAPTER_SELECT_NOTE := ""
# 챕터 버튼 오른쪽의 작은 글씨. {스테이지}를 넣으면 그 챕터의 첫 스테이지 이름이 나옵니다.
const CHAPTER_SELECT_FROM := ""
const CHAPTER_SELECT_CLEARED := "클리어"


# ------------------------------------------------------------------------------
#  3. 일시 정지 화면
# ------------------------------------------------------------------------------
const PAUSE_EYEBROW := "PAUSED"
const PAUSE_HEADING := "일시 정지"
const PAUSE_CONTINUE := "계속하기"
const PAUSE_RETRY := "체크포인트부터"
const PAUSE_TO_TITLE := "타이틀로"
const PAUSE_HELP := ""
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
# 2챕터부터 조작표 아래에 더해지는 줄. 키 그림은 Space+좌클릭, S+우클릭입니다.
const CONTROLS_AIR_ABSORB := "뛰어서 공중에서 흡수"
const CONTROLS_DOWN_RELEASE := "발밑으로 충격파 · 운동량 50"
# 3챕터부터 더해지는 줄. 키 그림은 좌클릭+우클릭입니다.
const CONTROLS_REFLECT := "막는 중 우클릭 · 반사"


# ------------------------------------------------------------------------------
#  4. 플레이 화면 표시 (HUD)
# ------------------------------------------------------------------------------
# 왼쪽 위와 시작 배너의 스테이지 번호.
const HUD_STAGE := "STAGE {번호}"
const HUD_STAGE_UNLISTED := "STAGE"
const HUD_PRACTICE := "PRACTICE"
# 시작 배너에서 체크포인트부터 이어 시작할 때의 부제.
const HUD_FROM_CHECKPOINT := "체크포인트  ·  {구간}"
# 말풍선의 이름표.
const HUD_SPEAKER := "세라"
# 운동량이 모자란데 대시나 충격파를 눌렀을 때.
const HUD_NOT_ENOUGH := "힘이 모자라… 운동량이 {숫자} 필요해"
# 보스 체력 표시.
const HUD_BOSS := "BOSS"
const HUD_BOSS_DORMANT := "대기 중"
# 클리어 화면.
const CLEAR_HEADLINE := "STAGE CLEAR"
# 챕터의 마지막 스테이지를 끝냈을 때의 큰 제목. 위에 챕터 표시가 붙습니다.
# 스테이지 연습에서는 그대로 CLEAR_HEADLINE입니다.
const CLEAR_CHAPTER_HEADLINE := "CHAPTER CLEAR"
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
# 캠페인의 마지막 스테이지를 깼을 때 E 옆의 글씨. 누르면 에필로그가 나옵니다.
const CLEAR_TO_EPILOGUE := "에필로그"


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
const NOTE_SHIELDED := "차폐 중"
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
const REACTOR_NOTE_CORE_SHUT := "코어 밀폐"
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
const SECTOR_NOTE_RAM_ARMOR := "전면 장갑"
# 돌진을 받아냈을 때. 뒤에 얻은 양이 붙습니다.
const SECTOR_NOTE_RAM_CAUGHT := "돌진 흡수 · 기체 정지"
const SECTOR_NOTE_RAM_CAUGHT_PRECISE := "정밀 흡수 · 돌진 정지"
const SECTOR_NOTE_DRONE_DOWN := "드론 격추"
const SECTOR_NOTE_RELAY := "릴레이 연결"
const SECTOR_NOTE_TIMED_RELAY := "시한 릴레이 작동"

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
const YARD_NOTE_CORE_SHUT := "집게 잠김"
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
const WHEEL_NOTE_SHIELD_CUT := "차폐 해제"
# 돌진을 받아냈을 때. 뒤에 얻은 양이 붙습니다.
const WHEEL_NOTE_CHARGE_CAUGHT := "돌진 흡수 · 포어맨 정지"
const WHEEL_NOTE_CHARGE_CAUGHT_PRECISE := "정밀 흡수 · 포어맨 정지"
# 바퀴에서 떨어진 화물을 받았을 때. 뒤에 얻은 양이 붙습니다.
const WHEEL_NOTE_LOAD_CAUGHT := "관성 흡수 · 코어 노출"
const WHEEL_NOTE_CORE_SHUT := "코어 밀폐"
# 마지막 장면.
const WHEEL_NOTE_FINALE := "대관성륜의 운동량이 슈트로 쏟아진다"
const WHEEL_NOTE_WRONG_WAY := "앞이 아니라 하늘로"
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


# ------------------------------------------------------------------------------
#  14. 2챕터 공통 (열차, 돌풍, 해치, 포대, 방패 경비, 투하기, 새 능력)
# ------------------------------------------------------------------------------
#  2챕터부터는 1챕터에서 배운 조작은 다시 안내하지 않고, 처음 나오는 것만
#  한 번씩 알려 줍니다.
const NOTE_FRONT_SHIELD := "방패에 막힘"
const SECTOR_NOTE_TURRET_DOWN := "포대 파괴"
const SECTOR_NOTE_BOMBER_DOWN := "투하기 격추"
const SECTOR_NOTE_HATCH := "해치 파괴"
# 투하기의 파란 통을 받았을 때. 뒤에 얻은 양이 붙습니다.
const SECTOR_NOTE_CANISTER := "투하물 흡수"
const SECTOR_NOTE_BLAST_EVADED := "폭발 회피"
# 공중에서 탄을 받았을 때. 뒤에 얻은 양이 붙습니다.
const NOTE_AIR_ABSORB := "공중 흡수"
const NOTE_AIR_ABSORB_PRECISE := "공중 정밀 흡수"
# 열차 다리. 신호가 빨개지면 곧 열차가 옵니다.
const SECTOR_HINT_TRAIN := ["열차 지붕이 다리가 돼. 올라타서 건너자.", "신호가 빨개지면 곧 열차가 와"]
# 돌풍 구역에 처음 들어갔을 때.
const SECTOR_HINT_GUST := ["바람이 세. 바람을 등지면 멀리, 거스르면 짧게 뛰어."]
# 포대가 처음 조준할 때. [좌클릭]
const SECTOR_HINT_TURRET := ["포대야. 탄을 받아서 그대로 돌려주자.", "포대를 보고 길게 눌러 줘"]
# 머리 위로 지나가는 탄. [Space + 좌클릭]
const SECTOR_HINT_AIR_CATCH := ["탄이 머리 위로 지나가. 뛰어서 받을게.", "뛰고 나서 탄을 보고 길게 눌러 줘"]
# 점프로 못 오르는 높은 곳. [S + 우클릭]
const SECTOR_HINT_DOWN := ["너무 높아. 발밑으로 쏘면 그 반동으로 튀어 올라.", "벽 앞에서 같이 눌러 줘"]
# 금 간 해치. [S + 우클릭]
const SECTOR_HINT_HATCH := ["금 간 해치야. 발밑으로 쏘면 깨져.", "해치 위에서 같이 눌러 줘"]
# 방패 경비. [S + 우클릭]
const SECTOR_HINT_FRONT_GUARD := ["방패 때문에 정면은 안 통해. 머리 위에서 내리꽂자.", "튀어 올라 경비 위에서 같이 눌러 줘"]
# 투하기가 파란 통을 떨어뜨릴 때. [좌클릭]
const SECTOR_HINT_BOMBER_CATCH := ["파란 통은 받을 수 있어.", "떨어지는 자리에서 길게 눌러 줘"]
# 투하기가 빨간 통을 떨어뜨릴 때.
const SECTOR_HINT_BOMBER_RED := ["빨간 통은 터져! 떨어지는 자리에서 비켜."]
# 투하기가 옆으로 비켜났을 때. [W + 우클릭]
const SECTOR_HINT_BOMBER_SHOT := ["옆으로 비켜났어. 지금 대각선으로!", "비스듬히 아래에서 같이 눌러 줘"]


# ------------------------------------------------------------------------------
#  15. 스테이지 2-3 · 장갑 열차 (보스)
# ------------------------------------------------------------------------------
const TRAIN_NOTE_WAKE := "장갑 열차 기동"
# 관성탄을 공중에서 받았을 때.
const TRAIN_NOTE_SHELL_CAUGHT := "관성탄 흡수 · 포문 개방"
const TRAIN_NOTE_CORE_SHUT := "포문 잠김"
const TRAIN_NOTE_STOPPED := "장갑 열차 정지"
# 보스 체력 표시 오른쪽의 상태.
const TRAIN_STATUS_SHUT := "포문 잠김"
const TRAIN_STATUS_OPEN := "코어 노출"
const TRAIN_STATUS_STOPPED := "정지"
# 관성탄이 날아올 때. [Space + 좌클릭]
const TRAIN_HINT_SHELL := ["큰 탄은 머리 위로 지나가. 뛰어서 받아 내자.", "뛰고 나서 열차를 보고 길게 눌러 줘"]
# 포문이 열렸을 때. [우클릭]
const TRAIN_HINT_CORE := ["포문이 열렸어! 앞쪽 코어야.", "다가가서 코어를 보고 눌러 줘"]


# ------------------------------------------------------------------------------
#  16. 스테이지 2-6 · 스트래들 캐리어 (보스)
# ------------------------------------------------------------------------------
const CARRIER_NOTE_WAKE := "캐리어 기동"
const CARRIER_NOTE_CAUGHT := "컨테이너 흡수 · 지붕 개방"
const CARRIER_NOTE_SLAB_EVADED := "과적 컨테이너 회피"
const CARRIER_NOTE_CORE_SHUT := "지붕 잠김"
const CARRIER_NOTE_SHAKEN := "흔들기 · 지붕에서 떨어짐"
const CARRIER_NOTE_STOPPED := "캐리어 정지"
const CARRIER_STATUS_SHUT := "지붕 잠김"
const CARRIER_STATUS_OPEN := "지붕 코어 노출"
const CARRIER_STATUS_STOPPED := "정지"
# 파란 컨테이너가 떨어질 때. [좌클릭]
const CARRIER_HINT_CATCH := ["파란 컨테이너는 받을 수 있어. 받으면 지붕이 열려.", "떨어지는 자리에서 길게 눌러 줘"]
# 빨간 컨테이너.
const CARRIER_HINT_DODGE := ["빨간 건 너무 무거워. 비켜!"]
# 지붕이 열렸을 때. [S + 우클릭]
const CARRIER_HINT_CLIMB := ["지붕이 열렸어. 발밑으로 쏴서 지붕에 올라가자.", "캐리어 밑에서 같이 눌러 줘"]
# 지붕 위, 코어 바로 위에서. [S + 우클릭]
const CARRIER_HINT_STOMP := ["코어 바로 위야. 내리꽂자!", "같이 눌러 줘"]


# ------------------------------------------------------------------------------
#  17. 스테이지 2-9 · 디스패처 (2챕터 최종 보스)
# ------------------------------------------------------------------------------
const DISPATCHER_NOTE_WAKE := "디스패처 기동"
const DISPATCHER_NOTE_SHELL := "관성탄 흡수 · 신호 차폐 해제"
const DISPATCHER_NOTE_SHIELDED := "신호 차폐"
const DISPATCHER_NOTE_CAUGHT := "컨테이너 흡수 · 지붕 개방"
const DISPATCHER_NOTE_ROOF_SHUT := "지붕 잠김"
const DISPATCHER_NOTE_WIND := "바람이 바뀐다"
const DISPATCHER_NOTE_STOPPED := "디스패처 정지"
const DISPATCHER_STATUS_SIGNAL := "신호 차폐"
const DISPATCHER_STATUS_OPEN := "코어 노출"
const DISPATCHER_STATUS_ROOF := "지붕 잠김"
const DISPATCHER_STATUS_STOPPED := "정지"
# 신호탑이 관성탄을 쏠 때. [Space + 좌클릭]
const DISPATCHER_HINT_SHELL := ["신호탑이 관성탄을 쏴. 공중에서 받으면 차폐가 풀려.", "뛰고 나서 신호탑을 보고 길게 눌러 줘"]
# 차폐가 풀렸을 때. [W + 우클릭]
const DISPATCHER_HINT_CORE := ["차폐가 풀렸어! 바닥 표식에서 대각선으로.", "바닥 표식 위에서 같이 눌러 줘"]
# 파란 컨테이너. [좌클릭]
const DISPATCHER_HINT_CATCH := ["파란 컨테이너야. 받으면 지붕이 열려.", "떨어지는 자리에서 길게 눌러 줘"]
# 지붕이 열렸을 때. [S + 우클릭]
const DISPATCHER_HINT_STOMP := ["지붕으로 튀어 올라서 내리꽂자.", "밑에서 한 번, 지붕 위에서 한 번"]


# ------------------------------------------------------------------------------
#  18. 3챕터 공통 (반사, 기우는 갑판, 화물 통, 거울 포대, 반사 표적, 추적탄,
#      흡수 경비, 저중력 실험실)
# ------------------------------------------------------------------------------
#  3챕터도 처음 나오는 것만 한 번씩 알려 줍니다. 반사의 키 그림은
#  좌클릭+우클릭(위로 반사는 좌클릭+W+우클릭)입니다.
# 탄을 반사했을 때.
const NOTE_REFLECT := "반사"
const NOTE_REFLECT_AIR := "공중 반사"
const SECTOR_NOTE_MIRROR := "거울에 반사됨"
const SECTOR_NOTE_MIRROR_DOWN := "거울 포대 파괴"
const SECTOR_NOTE_LAUNCHER_ARMOR := "장갑"
const SECTOR_NOTE_LAUNCHER_DOWN := "발사기 파괴"
const SECTOR_NOTE_ABSORBED := "흡수됨"
const SECTOR_NOTE_ABSORBER_DOWN := "흡수 경비 쓰러짐"
const SECTOR_NOTE_TARGET := "표적 명중"
const SECTOR_NOTE_TARGET_SHOCK := ""
# 추적탄이나 화물 통을 받았을 때. 뒤에 얻은 양이 붙습니다.
const SECTOR_NOTE_MISSILE := "추적탄 흡수"
const SECTOR_NOTE_BARREL := "화물 통 흡수"
# 탄이 처음 날아올 때. [좌클릭 + 우클릭]
const SECTOR_HINT_REFLECT := ["막고 있다가 닿기 직전에 우클릭하면 탄을 되돌려 줄 수 있어.", "막는 중 닿기 직전에 눌러 줘"]
# 배가 처음 기울 때.
const SECTOR_HINT_TILT := ["배가 기울어! 비탈 아래로 미끄러져."]
# 파란 화물 통이 굴러올 때. [좌클릭]
const SECTOR_HINT_BARREL := ["화물 통이 굴러와. 파란 건 받아서 힘으로 쓰자.", "통을 보고 길게 눌러 줘"]
# 빨간 화물 통이 굴러올 때. [Space]
const SECTOR_HINT_BARREL_RED := ["빨간 통은 너무 무거워. 뛰어넘자!", "닿기 직전에 눌러 줘"]
# 거울 포대. [좌클릭 + 우클릭]
const SECTOR_HINT_MIRROR := ["거울 포대야. 충격파는 되돌아와. 저 탄을 반사해서 맞히자.", "막는 중 닿기 직전에 눌러 줘"]
# 반사 표적. [좌클릭 + W + 우클릭]
const SECTOR_HINT_TARGET := ["표적은 반사한 탄에만 반응해. 표식에서 위로 되돌리자.", "바닥 표식에서 W를 누른 채 반사"]
# 추적탄이 날아올 때. [좌클릭 + 우클릭]
const SECTOR_HINT_HOMING := ["추적탄이야! 받거나, 반사해서 발사기로 돌려보내자.", "막는 중 닿기 직전에 눌러 줘"]
# 흡수 경비. [좌클릭 + 우클릭]
const SECTOR_HINT_ABSORBER := ["흡수 경비야. 충격파를 먹고 큰 탄으로 돌려줘.", "큰 탄이 오면 막는 중 반사"]
const SECTOR_HINT_ABSORBER_ECHO := ["큰 탄이 돌아온다! 반사해서 되돌려 줘.", "막는 중 닿기 직전에 눌러 줘"]
# 저중력 구역에 처음 들어갔을 때.
const SECTOR_HINT_LOW_GRAVITY := ["중력이 약해. 높이 뛸 수 있고, 탄도 느려져."]


# ------------------------------------------------------------------------------
#  19. 스테이지 3-3 · 키잡이 (보스)
# ------------------------------------------------------------------------------
const HELM_NOTE_WAKE := "키잡이 기동"
# 충격파가 거울 함교에 맞았을 때.
const HELM_NOTE_MIRROR := "거울 함교"
# 포문이 닫혀 있을 때 되돌린 탄이 맞았을 때.
const HELM_NOTE_SHUT := "포문 닫힘"
# 키가 없는 곳에 되돌린 탄이 맞았을 때.
const HELM_NOTE_ARMOR := "장갑"
const HELM_NOTE_STOPPED := "키잡이 정지"
const HELM_STATUS_SHUT := "거울 차폐"
const HELM_STATUS_OPEN := "포문 개방"
const HELM_STATUS_STOPPED := "정지"
# 1페이즈. [좌클릭 + 우클릭]
const HELM_HINT_REFLECT := ["거울이라 충격파는 되돌아와. 저 탄을 반사해서 포문에 넣자.", "막는 중 닿기 직전에 눌러 줘"]
# 2페이즈, 키가 높은 창에 있을 때. [좌클릭 + W + 우클릭]
const HELM_HINT_HIGH := ["키가 위 창으로 올라갔어. 표식에서 위로 되돌리자.", "바닥 표식에서 W를 누른 채 반사"]


# ------------------------------------------------------------------------------
#  20. 스테이지 3-6 · 시추 리그 (보스)
# ------------------------------------------------------------------------------
const RIG_NOTE_WAKE := "시추 리그 기동"
const RIG_NOTE_POD_SHUT := "포드 잠김"
const RIG_NOTE_DRANK := "흡수 접시"
const RIG_NOTE_STOPPED := "시추 리그 정지"
const RIG_STATUS_POD := "포드 개방"
const RIG_STATUS_DISH := "흡수 접시"
const RIG_STATUS_STOPPED := "정지"
# 1페이즈, 추적탄이 날아올 때. [좌클릭 + 우클릭]
const RIG_HINT_MISSILE := ["추적탄을 포드로 돌려보내자.", "막는 중 닿기 직전에 눌러 줘"]
# 2페이즈, 포드가 잠겼을 때. [우클릭]
const RIG_HINT_DISH := ["포드가 잠겼어. 접시에 쏘면 큰 탄으로 돌아와. 그걸 되돌리자.", "접시를 보고 눌러 줘"]
# 굴착기가 내려찍을 때.
const RIG_HINT_DRILL := ["굴착기가 내려찍어! 붉은 파동을 뛰어넘자."]


# ------------------------------------------------------------------------------
#  21. 스테이지 3-9 · 에코 (3챕터 최종 보스)
# ------------------------------------------------------------------------------
const ECHO_NOTE_WAKE := "에코 기동"
# 에코가 세라의 충격파를 받았을 때.
const ECHO_NOTE_ABSORBED := "에코가 흡수"
# 되돌린 탄이 에코에게 맞았을 때.
const ECHO_NOTE_STAGGER := "균형 붕괴"
# 3페이즈에서 에코가 되돌린 탄을 한 번 더 되받아쳤을 때.
const ECHO_NOTE_RALLY := "에코가 되받아쳤다"
const ECHO_NOTE_STOPPED := "에코 정지"
const ECHO_STATUS_GUARD := "흡수 자세"
const ECHO_STATUS_OPEN := "균형 붕괴"
const ECHO_STATUS_STOPPED := "정지"
# 페이즈가 바뀔 때 에코가 하는 말. 화면 가운데 알림으로 나옵니다.
const ECHO_TAUNTS := [
	"에코: 받은 만큼 돌려준다. 네가 가르쳐 준 거야, 세라.",
	"에코: 3년 동안 여기서 힘을 모았어. 바퀴도, 항구도.",
]
# 에코가 탄을 쏠 때. [좌클릭 + 우클릭]
const ECHO_HINT_REFLECT := ["에코는 내 충격파를 받아서 돌려줘. 먼저 저 탄을 되돌리자.", "막는 중 닿기 직전에 눌러 줘"]
# 운동량이 모자랄 때. [좌클릭]
const ECHO_HINT_ENERGY := ["힘이 모자라. 탄 하나는 받아서 힘으로 바꾸자.", "탄을 보고 길게 눌러 줘"]
# 에코가 흔들렸을 때. [우클릭]
const ECHO_HINT_STRIKE := ["흔들렸어! 지금이야.", "에코를 보고 눌러 줘"]
# 에코가 돌진할 때.
const ECHO_HINT_DASH := ["돌진이야! 뛰어넘자."]


# ------------------------------------------------------------------------------
#  22. 에필로그 · 캠페인의 마지막 스테이지를 깬 뒤
# ------------------------------------------------------------------------------
#  클리어 화면에서 E를 누르면 한 줄씩 나타납니다. 줄 수는 바꿔도 됩니다.
const EPILOGUE_EYEBROW := "EPILOGUE"
const EPILOGUE := [
	"에코: …네 슈트의 제한을 푼 건 내가 아니야, 세라.",
	"에코: 바퀴도, 항구도, 이 기지도. 전부 한 사람이 그린 설계도였어.",
	"보조 관제 신호의 발신지는 켈더가 아니었다.",
	"그 끝에, 설계자가 있다.",
]
const EPILOGUE_END := "다음 이야기에서"


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


## Stages in one act. A chapter of three acts holds nine stages; STAGES lists
## every chapter's stages one after another, in campaign order.
const STAGES_PER_ACT := 3


## How many stages the chapter holds, or 0 for no chapter.
static func chapter_size(chapter: int) -> int:
	if chapter < 0 or chapter >= CHAPTERS.size():
		return 0
	return CHAPTERS[chapter]["acts"].size() * STAGES_PER_ACT


## The campaign index of the chapter's first stage.
static func chapter_start(chapter: int) -> int:
	var first := 0
	for earlier in clampi(chapter, 0, CHAPTERS.size()):
		first += chapter_size(earlier)
	return first


## The chapter the stage at `index` belongs to, or -1 for a scene outside every chapter.
static func chapter_of(index: int) -> int:
	if index < 0:
		return -1
	var end := 0
	for chapter in CHAPTERS.size():
		end += chapter_size(chapter)
		if index < end:
			return chapter
	return -1


static func chapter_name(chapter: int) -> String:
	return CHAPTERS[chapter]["name"] if chapter >= 0 and chapter < CHAPTERS.size() else ""


## "CHAPTER 1  ·  포어맨", or an empty string for no chapter.
static func chapter_label(chapter: int) -> String:
	if chapter < 0 or chapter >= CHAPTERS.size():
		return ""
	return CHAPTER_LABEL.format({"번호": chapter + 1, "이름": chapter_name(chapter)})


## The upper line of the card that opens the chapter: "CHAPTER 1".
static func chapter_card(chapter: int) -> String:
	if chapter < 0 or chapter >= CHAPTERS.size():
		return ""
	return CHAPTER_CARD.format({"번호": chapter + 1, "이름": chapter_name(chapter)})


## True for the first stage of a chapter.
static func opens_chapter(index: int) -> bool:
	var chapter := chapter_of(index)
	return chapter >= 0 and index == chapter_start(chapter)


## True for the last stage of a chapter.
static func closes_chapter(index: int) -> bool:
	var chapter := chapter_of(index)
	return chapter >= 0 and index == chapter_start(chapter) + chapter_size(chapter) - 1


## The stage's place in its own chapter, counting from 1.
static func stage_in_chapter(index: int) -> int:
	var chapter := chapter_of(index)
	return index - chapter_start(chapter) + 1 if chapter >= 0 else index + 1


## "ACT 2  ·  하강" for the act the stage belongs to, or an empty string for no chapter.
static func act_label(index: int) -> String:
	var chapter := chapter_of(index)
	if chapter < 0:
		return ""
	var acts: Array = CHAPTERS[chapter]["acts"]
	var act := clampi(floori((index - chapter_start(chapter)) / float(STAGES_PER_ACT)), 0, acts.size() - 1)
	return ACT_LABEL.format({"막": act + 1, "이름": acts[act]})


## "STAGE 04", numbered within the stage's chapter.
static func stage_number(index: int) -> String:
	return HUD_STAGE.format({"번호": "%02d" % stage_in_chapter(index)})


## "냉각탑으로", "동력로로": the name with the particle that fits its last sound.
static func toward(name: String) -> String:
	if name.is_empty():
		return ""
	var code := name.unicode_at(name.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return name + "(으)로"
	var final_consonant := (code - 0xAC00) % 28
	return name + ("로" if final_consonant == 0 or final_consonant == 8 else "으로")
