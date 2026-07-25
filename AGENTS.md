# 任务收尾协议

- 每个独立开发阶段结束时审查完整 diff，删除临时诊断、测试节点、临时脚本和其他取证残留。
- 运行当前项目适用的 test、lint、构建、启动烟雾测试和 `git diff --check`；不存在的检查项不额外引入工具。
- 更新 `CURRENT_STATE.md`；重大决策同时更新已有的 `DECISIONS.md` 或 `CHANGELOG.md`。
- 只有已通过验收且属于当前阶段的修改才能形成原子提交，不混入无关 dirty changes。
- push、发布、部署和创建远端仓库必须取得用户明确授权。
- 长任务中间使用可回滚 checkpoint；不把 `git stash` 当作长期备份。
