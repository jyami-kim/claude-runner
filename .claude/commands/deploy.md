# Deploy Command

claude-runner 프로젝트의 커밋 → 푸시 → CI 확인 → (선택) 릴리스를 자동으로 수행합니다.

## 실행 순서

### 1. 로컬 빌드 + 테스트
```bash
swift build
swift test
```
- 실패 시 즉시 중단하고 에러를 보여준다.

### 2. Git Commit
- `git status`와 `git diff`로 변경 사항 확인
- `git log --oneline -3`으로 최근 커밋 스타일 확인
- 변경 내용을 분석하여 한글 커밋 메시지 작성
- 변경 사항이 없으면 "커밋할 변경 사항이 없습니다" 출력 후 중단

### 3. Git Push
```bash
git push
```

### 4. CI 확인
- `GH_HOST=github.com gh run list --limit 1`로 최신 CI 실행 확인
- 30초 간격으로 최대 3분 대기하며 CI 완료 확인
- `GH_HOST=github.com gh run view <run-id>`로 결과 확인
- CI 실패 시 `GH_HOST=github.com gh run view <run-id> --log-failed`로 로그 출력
- CI 성공/실패 결과를 사용자에게 보고

### 5. (선택) Release
- 사용자가 `/deploy release` 또는 인자에 `release`를 포함한 경우에만 실행
- CI가 성공한 후 실행한다
- 사용자에게 릴리스 버전을 물어본다 (예: 0.4.0)
- `./release.sh <version>` 스크립트를 실행한다:
  1. Info.plist의 `CFBundleShortVersionString`을 새 버전으로 업데이트
  2. `swift build` + `swift test` 실행 (릴리스 전 최종 확인)
  3. 버전 범프 커밋 생성
  4. `v<version>` git 태그 생성
  5. 커밋 + 태그 푸시
- GitHub Actions `release.yml`이 자동으로:
  1. Universal binary 빌드 (arm64 + x86_64)
  2. GitHub Release 생성 (zip 첨부)
  3. Homebrew cask 업데이트 (`jyami-kim/homebrew-tap`)
    - postflight: quarantine 속성 제거 + 앱 자동 재실행
- Release CI 완료까지 대기 후 결과 보고
- Release CI 확인:
  - `GH_HOST=github.com gh run list --workflow=release.yml --limit 1`
  - 완료 후 `https://github.com/jyami-kim/claude-runner/releases/tag/v<version>` 링크 제공

## 사용법

```
/deploy          # 커밋 → 푸시 → CI 확인
/deploy release  # 커밋 → 푸시 → CI 확인 → 릴리스 (버전 범프 + 태그 + Homebrew cask 업데이트)
```

## 주의사항

- GitHub Actions 확인에는 `GH_HOST=github.com` 환경변수가 필요하다
- 릴리스는 main 브랜치에서만 수행한다
- CI 실패 시 릴리스를 진행하지 않는다
- release.sh는 working tree가 clean한 상태에서만 실행 가능하다
- Homebrew cask 업데이트에는 `TAP_TOKEN` GitHub secret이 필요하다
