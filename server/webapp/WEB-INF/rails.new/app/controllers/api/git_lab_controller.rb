##########################################################################
# Copyright 2017 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

class Api::GitLabController < Api::ApiController
  before_action :verify_content_origin
  before_action :allow_only_push_event
  before_action :verify_payload

  def notify
    repo_full_name = payload['project']['path_with_namespace']
    repo_html_url = payload['project']['http_url']
    repo_branch = payload['ref'].gsub('refs/heads/', '')

    repo_host_name = URI.parse(repo_html_url).host

    possible_urls = %W(
      https://#{repo_host_name}/#{repo_full_name}
      https://#{repo_host_name}/#{repo_full_name}/
      https://#{repo_host_name}/#{repo_full_name}.git
      https://#{repo_host_name}/#{repo_full_name}.git/
      http://#{repo_host_name}/#{repo_full_name}
      http://#{repo_host_name}/#{repo_full_name}/
      http://#{repo_host_name}/#{repo_full_name}.git
      http://#{repo_host_name}/#{repo_full_name}.git/
      git://#{repo_host_name}/#{repo_full_name}
      git://#{repo_host_name}/#{repo_full_name}/
      git://#{repo_host_name}/#{repo_full_name}.git
      git://#{repo_host_name}/#{repo_full_name}.git/
      git@#{repo_host_name}:#{repo_full_name}
      git@#{repo_host_name}:#{repo_full_name}/
      git@#{repo_host_name}:#{repo_full_name}.git
      git@#{repo_host_name}:#{repo_full_name}.git/
    )

    if material_update_service.updateGitMaterial(repo_branch, possible_urls)
      render text: 'OK!', content_type: 'text/plain', status: :accepted, layout: nil
    else
      render text: 'No matching materials!', content_type: 'text/plain', status: :accepted, layout: nil
    end
  end

  protected

  def allow_only_push_event
    unless request.headers['X-Gitlab-Event'] == 'Push Hook'
      render text: "Ignoring event of type `#{request.headers['X-Gitlab-Event']}'", content_type: 'text/plain', status: :accepted, layout: nil
    end
  end

  def verify_payload
    if payload.blank?
      render text: 'Could not understand the payload!', content_type: 'text/plain', status: :bad_request, layout: nil
    end
  rescue => e
    Rails.logger.warn('Could not understand gitlab webhook payload:')
    Rails.logger.warn(e)
    render text: 'Could not understand the payload!', content_type: 'text/plain', status: :bad_request, layout: nil
  end

  def payload
    if request.content_mime_type == :json
      JSON.parse(request.raw_post)
    end
  end

  def verify_content_origin
    if request.headers['X-Gitlab-Token'].blank?
      return render text: "No token specified in the `X-Gitlab-Token' header!", content_type: 'text/plain', status: :bad_request, layout: nil
    end

    unless Rack::Utils.secure_compare(webhook_secret, request.headers['X-Gitlab-Token'])
      render text: "Token specified in the `X-Gitlab-Token' header did not match!", content_type: 'text/plain', status: :bad_request, layout: nil
    end
  end

  def webhook_secret
    server_config_service.getWebhookSecret
  end
end
