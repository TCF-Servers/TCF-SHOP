class Admin::RconCommandTemplatesController < Admin::BaseController
  def index
    @templates = policy_scope(RconCommandTemplate).order(:name)
    @template = RconCommandTemplate.new
  end

  def new
    @template = RconCommandTemplate.new
    authorize @template
  end

  def create
    @template = RconCommandTemplate.new(template_params)
    authorize @template

    if @template.save
      redirect_to admin_rcon_command_templates_path, notice: "Template créé avec succès"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @template = RconCommandTemplate.find(params[:id])
    authorize @template
    @template.destroy
    redirect_to admin_rcon_command_templates_path, notice: "Template supprimé"
  end

  private

  def template_params
    params.require(:rcon_command_template).permit(:name, :command_template, :description, :required_role, :requires_player, :enabled)
  end
end
