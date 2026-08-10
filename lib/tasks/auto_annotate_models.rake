# NOTE: only doing this in development as some production environments (Heroku)
# NOTE: are sensitive to local FS writes, and besides -- it's just not proper
# NOTE: to have a dev-mode tool do its thing in production.

# Engine rake layout exposes annotate as app:annotate_models; skip auto-hook on
# db:migrate so migrate does not fail looking for top-level annotate_models.
# Annotate is a CommandTower *development* dependency of the gem repo, not a
# runtime dependency for downstream hosts — guard the require.
if Rails.env.development?
  begin
    require "annotate"
  rescue LoadError
    # Host applications without the annotate gem skip model annotation hooks.
  else
    task :set_annotation_options do
      Annotate.set_defaults(
        "active_admin" => "false",
        "models" => "true",
        "model_dir" => "app/models",
        "skip_on_db_migrate" => "true",
        "show_foreign_keys" => "true",
        "show_indexes" => "true"
      )
    end

    Annotate.load_tasks
  end
end
