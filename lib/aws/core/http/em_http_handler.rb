require 'em-aws'
module AWS
  module Core
    module Http
      class EMHttpHandler < EM::AWS::HttpHandler
      end
    end
  end

  # We move this from AWS::Http to AWS::Core::Http, but we want the
  # previous default handler to remain accessible from its old namespace
  # @private
  module Http
    class EMHttpHandler < Core::Http::EMHttpHandler; end
  end
end
