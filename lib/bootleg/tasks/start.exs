alias Bootleg.{UI, Config}
use Bootleg.Config

task :start do
  remote :app do
    "bin/#{Config.app} start"
  end
  UI.info "#{Config.app} started"
  :ok
end
