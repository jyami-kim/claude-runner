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
- Co-Authored-By 서명은 포함하지 않는다
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
- 사용자에게 릴리스 버전을 물어본다 (예: v1.1.0)
- `git tag <version>` → `git push --tags`
- GitHub Actions release.yml이 자동으로 universal binary 빌드 + GitHub Release 생성
- 릴리스 CI 완료까지 대기 후 결과 보고

## 사용법

```
/deploy          # 커밋 → 푸시 → CI 확인
/deploy release  # 커밋 → 푸시 → CI 확인 → 릴리스 태그
```

## 주의사항

- GitHub Actions 확인에는 `GH_HOST=github.com` 환경변수가 필요하다
- 릴리스는 main 브랜치에서만 수행한다
- CI 실패 시 릴리스를 진행하지 않는다
