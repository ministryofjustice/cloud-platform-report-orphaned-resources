module OrphanedResources
  class Lister

    private

    def clean_list(list)
      list
        .flatten
        .uniq
        .reject(&:nil?)
        .reject(&:empty?)
        .sort
    end
  end
end
