module Settings
  class SkillsController < ApplicationController
    before_action :require_authentication
    before_action :set_skill, only: [ :show, :edit, :update, :destroy, :export, :execute ]

    def index
      @skills = Skill.for_user(current_user)
      @skills = @skills.by_category(params[:category]) if params[:category].present?
      @skills = @skills.order(:category, :name)
      @categories = Skill::CATEGORIES
    end

    def new
      @skill = Skill.new(source: "created")
    end

    def create
      @skill = Skill.new(skill_params)
      @skill.user = current_user
      @skill.source = "created"

      if @skill.save
        respond_to do |format|
          format.html { redirect_to settings_skills_path, notice: "Skill '#{@skill.name}' created." }
          format.json { render json: { success: true, id: @skill.id, slug: @skill.slug } }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { success: false, errors: @skill.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def show
    end

    def edit
    end

    def update
      if @skill.update(skill_params)
        respond_to do |format|
          format.html { redirect_to settings_skills_path, notice: "Skill '#{@skill.name}' updated." }
          format.json { render json: { success: true } }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { success: false, errors: @skill.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      name = @skill.name
      @skill.destroy

      respond_to do |format|
        format.html { redirect_to settings_skills_path, notice: "Skill '#{name}' deleted." }
        format.json { render json: { success: true } }
      end
    end

    def import
      if params[:file].blank?
        respond_to do |format|
          format.html { redirect_to settings_skills_path, alert: "Please select a file to import." }
          format.json { render json: { success: false, error: "No file provided" }, status: :unprocessable_entity }
        end
        return
      end

      content = params[:file].read
      skill = Skill.from_markdown!(content, user: current_user, filename: params[:file].original_filename)

      respond_to do |format|
        format.html { redirect_to settings_skills_path, notice: "Skill '#{skill.name}' imported successfully." }
        format.json { render json: { success: true, id: skill.id, slug: skill.slug } }
      end
    rescue Skills::InvalidFormatError => e
      respond_to do |format|
        format.html { redirect_to settings_skills_path, alert: "Import failed: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.html { redirect_to settings_skills_path, alert: "Import failed: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end

    def export
      markdown = @skill.to_markdown
      send_data markdown,
                filename: "#{@skill.slug}.md",
                type: "text/markdown",
                disposition: "attachment"
    end

    def export_all
      skills = Skill.for_user(current_user)

      if skills.empty?
        respond_to do |format|
          format.html { redirect_to settings_skills_path, alert: "No skills to export." }
          format.json { render json: { success: false, error: "No skills to export" }, status: :unprocessable_entity }
        end
        return
      end

      zip_data = Skills::BulkExporter.new(skills).to_zip
      send_data zip_data,
                filename: "skills-export-#{Date.current}.zip",
                type: "application/zip",
                disposition: "attachment"
    end

    def execute
      params_hash = params[:parameters]&.to_unsafe_h || {}
      result = @skill.execute(params_hash)

      render json: result
    rescue Skills::MissingParameterError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end

    private

    def require_authentication
      unless current_user
        redirect_to login_path, alert: "Please log in to access settings."
      end
    end

    def set_skill
      @skill = Skill.for_user(current_user).find(params[:id])
    end

    def skill_params
      params.require(:skill).permit(
        :name, :slug, :version, :description, :category,
        :prompt_template, :enabled
      )
    end
  end
end
