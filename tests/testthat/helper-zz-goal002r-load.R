project_root_goal002r <- if (dir.exists("R")) "." else file.path("..", "..")
source(file.path(project_root_goal002r, "scripts", "source_goal002r.R"))
source_goal002r(project_root_goal002r)
rm(project_root_goal002r)
