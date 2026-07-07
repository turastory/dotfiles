---
name: pr-tree-review-request
description: 작업을 마무리하고 팀에 리뷰를 요청하는 Slack 메시지를 만들 때 사용한다. 특히 여러 PR이 base로 물려 스택/트리를 이룰 때 의존 구조를 시각적으로(코드블록 트리 + 클릭 링크) 표현한 리뷰 요청 문구를 생성하고, 확인 후 본인 Slack DM으로 보낸다. "리뷰 요청 메시지 (생성)", "PR 스택 리뷰 요청", "이 PR들 리뷰 요청 슬랙에 공유", "리뷰 요청 문구 만들어줘", "스택 리뷰 부탁 메시지" 같은 요청이면 명시적으로 "트리"라는 단어가 없어도 사용한다. PR이 하나뿐이어도 리뷰 요청 메시지를 원하면 쓴다. pr-tree(구조·상태 소스)와 my-slack-tone(톤)을 조합한다.
---

# PR Tree Review Request

리뷰 요청을 팀에 공유하는 Slack 메시지를 만든다. PR이 여러 개 base로 물려 있으면 **왜 이 순서로 리뷰해야 하는지**가 한눈에 보이도록 의존 구조를 시각화하는 것이 이 스킬의 핵심이다. 트리 정의·정합성은 `pr-tree`가, 문장 톤은 `my-slack-tone`이 담당하고, 여기서는 그 둘을 엮어 메시지를 만들고 본인 DM으로 보낸다.

## 흐름

1. **대상 PR 집합을 정한다** — 아래 "PR 집합 결정".
2. **PR별 메타를 수집한다** — 번호 / `[scope] 제목` / URL / 상태 / base / LoC(additions+deletions). LoC는 크기 문구용(아래 "크기 판단").
3. **리뷰 요청 대상을 지정한다** — 사용자가 말한 것, 없으면 방금 열린/push된 leaf.
4. **메시지를 렌더한다** — 아래 "메시지 포맷". `my-slack-tone` 규칙을 적용한다.
5. **사용자에게 최종 문구를 보여주고 확인받은 뒤** 본인 DM으로 전송한다.

## PR 집합 결정

**우선순위 1 — pr-tree.tsv가 있으면 그게 single source of truth다.**
현재 작업이 워크스페이스 프로젝트(`~/workspaces/project/<name>/pr-tree.tsv`)로 관리되고 있으면 그 파일을 쓴다. 어느 프로젝트인지 애매하면 사용자에게 묻는다. 트리 구조와 상태는 점검 스크립트가 정적으로 그려주므로 재활용한다:

```bash
~/.agents/skills/pr-tree/check-pr-tree.sh --tree ~/workspaces/project/<name>/pr-tree.tsv --no-fetch
```

출력 맨 앞 트리 다이어그램이 base 관계 그림이고, tsv의 `status`(open/planned)와 PR 번호를 함께 읽는다.

**우선순위 2 — tsv가 없으면 현재 브랜치에서 스택을 추론한다.**
`gh`로 현재 브랜치의 PR과 base 체인을 따라 올라간다:

```bash
gh pr view <branch> --json number,title,url,state,isDraft,baseRefName
```

`baseRefName`이 `master`가 아니면 그 브랜치의 PR을 다시 조회해 체인을 잇는다. 추론한 결과가 맞는지 사용자에게 한 번 확인하고, 필요하면 pr-tree.tsv로 정식화할지 제안한다(강요하지 않는다).

## 상태 판정

각 PR을 다음으로 분류한다. gh state와 tsv status를 함께 본다.

| 상태 | 판정 | 트리 태그 | 링크 리스트 이모지 |
|---|---|---|---|
| 머지됨 | gh `MERGED` | `[merged]` | `:git-merged:` |
| 승인됨 | open, gh `reviewDecision == APPROVED` | `[approved]` | `:git-approved:` |
| 리뷰 요청 대상 | 이번에 리뷰 요청하는 것 | `[new]` | (아래 링크 리스트에서 강조) |
| 리뷰 중 | open, non-draft, 이미 요청함 | `[reviewing]` | `:ballot_box_with_check:` |
| 작업 중 | open draft 또는 tsv `planned` | `[WIP]` | `:construction:` |

승인 여부는 `gh pr view <번호> --json reviewDecision -q .reviewDecision`(`APPROVED`/`CHANGES_REQUESTED`/`REVIEW_REQUIRED`)로 확인한다.

## 메시지 포맷 (하이브리드)

구조는 **코드블록 트리**로 그리고(monospace, 들여쓰기 보존), 클릭·unfurl 되는 링크는 **코드블록 밖 리스트**로 둔다. 코드블록 안에서는 `:emoji:` shortcode가 렌더되지 않고 유니코드 이모지는 정렬을 깨므로, 트리에는 반드시 텍스트 상태 태그를 쓰고 이모지는 리스트에만 쓴다.

구성:

1. **멘션 줄** — 팀 전체면 유저그룹, 특정인이면 `@이름님,`. 멘션 ID는 추측하지 말고 기존 메시지/검색으로 확인한 것만 쓴다. product-pay-engineer 그룹은 `<!subteam^S095P0PHCLC>`.
2. **코드블록 트리** — `pr-tree.md` 그림 스타일(`├─`/`└─`/`│`)에 상태 태그를 붙이고, 리뷰 요청 대상 줄 끝에 `← 리뷰 요청`. 상태 태그는 세로로 정렬한다.
3. **코드블록 밖 링크 리스트** — `*리뷰 요청*` 한 줄 + 요청 대상마다 `이모지 <url|#번호> - 설명` 형식. **링크는 PR 번호(`#29838`)에만 걸고**, 그 뒤에 무엇을 하는 PR인지 한 줄 설명을 붙인다(제목을 그대로 쓰거나 더 짧게 풀어 써도 된다). base 의존이 리뷰 순서에 영향을 주면 설명 끝에 짧게 덧붙인다.
4. **맥락 1~3문장** — PR을 나눈 이유 / 배포 순서 / 데드라인 / 남은 작업 상태 + 크기(아래 "크기 판단"). 요청·결론이 앞, 배경은 뒤(my-slack-tone).

### 선형 체인 축약

스택이 단순 선형(가지 분기 없음)이고 3개 이하면 트리 그림 대신 화살표 한 줄로 줄여도 된다:

```
#28798 ─▶ #28801 ─▶ #28802   (뒤로 갈수록 앞 PR에 의존)
```

가지가 갈라지거나(forest/branch) PR이 많으면 전체 트리 그림을 쓴다.

### 예시

forest(root 2개 + 가지 1개) 리뷰 요청:

```
<!subteam^S095P0PHCLC>
결제 포인트 자동 사용 토글 PR입니다. 배포 순서 때문에 나눴습니다!

​```
master
 ├─ #28798  inapp-toggle        [merged]
 │   └─ #28801  대여/구매 라벨      [new]
 └─ #28900  serial-popup        [reviewing]
​```

*리뷰 요청*
• :ballot_box_with_check: <https://github.com/.../28801|#28801> - 대여/구매 라벨 분기, base가 #28798(머지됨)이라 그 다음 머지 예정
• 참고: #28900(serial-popup)은 별도 리뷰 진행 중입니다

diff 120줄 정도라 금방 보실 수 있습니다 :bow1:
```

(위 예시의 코드펜스 앞 zero-width 문자는 이 문서에서 중첩 코드블록을 보여주기 위한 것일 뿐, 실제 Slack 메시지엔 순수 ```` ``` ````만 쓴다.)

## 크기 판단

"크지 않다 / 금방 본다" 같은 문구는 느낌이 아니라 **PR LoC**로 판단한다. `gh`로 실제 숫자를 확인한다:

```bash
gh pr view <번호> --json additions,deletions -q '.additions + .deletions'
```

- **additions + deletions < 200** 이면 "크지 않다"고 말해도 된다. 그 이상이면 "크지 않다"고 쓰지 말고, 큰 이유(범위가 넓다/파일이 많다)를 짧게 인정하거나 크기 언급을 생략한다.
- LoC가 실제 리뷰 부담보다 **부풀려진** 경우 — 자동 생성 코드(gql codegen, proto/`*.pb.ts`, snapshot 등)나 반복되는 유사 코드(비슷한 케이스 나열, 대량 fixture)가 많으면 — 그 점을 가볍게 덧붙여 체감 리뷰량을 알려준다. 예: "diff는 400줄인데 절반이 gql codegen이라 실제 볼 건 얼마 안 됩니다", "케이스별로 비슷한 코드가 반복돼서 숫자만 큽니다". 판단이 애매하면 `gh pr view <번호> --json files`로 파일 목록을 보고 생성물/반복 여부를 확인한다.
- 여러 PR이면 합산하지 말고 각각 보거나 "다 합쳐도 N줄" 식으로 전체 규모를 한 번에 전한다.

## 톤

문장·이모지·멘션·`*굵게*`·`..` 종결 등은 `my-slack-tone` 스킬 규칙을 따른다. 특히 리뷰 요청은 요청 문구를 앞에 두고 배경은 뒤에, 인사 보일러플레이트 없이, 이모지는 0~2개. 문장 밀도가 애매하면 my-slack-tone을 참조한다.

## 전송

`my-slack-tone` 규칙대로 **보내기 전 최종 문구를 사용자에게 보여주고 확인받는다.** 승인하면 본인 DM으로 보낸다:

- 도구: `mcp__plugin_slack_slack__slack_send_message`
- 대상: 본인 Slack user id `U0AC0SM1081` (yoonho.na@ridi.com). DM이므로 이 user id를 channel로 전달한다.

사용자가 "그냥 문구만 줘"라고 하면 전송하지 말고 문구만 출력한다. 어디로 보낼지(팀 채널 등)를 따로 지정하면 그쪽으로 보내되, 채널/멘션 ID는 확인된 것만 쓴다.
