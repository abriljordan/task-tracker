#!/usr/bin/env ruby

require 'json'
require 'time'
require 'logger'

class TaskStorage
  def initialize(file_path)
    @file_path = file_path
  end

  def load
    File.exist?(@file_path) ? JSON.parse(File.read(@file_path)) : []
  rescue JSON::ParserError
    []
  end

  def save(tasks)
    File.write(@file_path, JSON.pretty_generate(tasks))
  rescue IOError, SystemCallError => e
    Logger.new(STDOUT).error("Failed to save tasks: #{e.message}")
  end
end

class TaskTracker
  VALID_STATUSES = ['todo', 'in-progress', 'done'].freeze

  def initialize
    @storage = TaskStorage.new('tasks.json')
    @tasks = @storage.load
    @logger = Logger.new(STDOUT)
  end

  def run(args)
    command = args.shift
    case command
    when 'add'
      add_task(args.join(' '))
    when 'update'
      update_task(args[0], args[1..-1].join(' '))
    when 'delete'
      delete_task(args[0])
    when 'mark'
      mark_task(args[0], args[1])
    when 'list'
      list_tasks(args[0])
    else
      @logger.warn("Unknown command. Use: add, update, delete, mark, or list.")
    end
  end

  private

  def add_task(description)
    task = {
      'id' => (@tasks.map { |t| t['id'].to_i }.max || 0) + 1,
      'description' => description,
      'status' => 'todo',
      'createdAt' => Time.now.iso8601,
      'updatedAt' => Time.now.iso8601
    }
    @tasks << task
    @storage.save(@tasks)
    @logger.info("Task added: #{task['id']} - #{task['description']}")
  end

  def update_task(id, description)
    task = find_task(id)
    if task
      task['description'] = description
      task['updatedAt'] = Time.now.iso8601
      @storage.save(@tasks)
      @logger.info("Task updated: #{task['id']} - #{task['description']}")
    else
      @logger.warn("Task not found with id: #{id}")
    end
  end

  def delete_task(id)
    @tasks.reject! { |t| t['id'].to_s == id }
    @storage.save(@tasks)
    @logger.info("Task deleted with id: #{id}")
  end

  def mark_task(id, status)
    task = find_task(id)
    if task
      if VALID_STATUSES.include?(status)
        task['status'] = status
        task['updatedAt'] = Time.now.iso8601
        @storage.save(@tasks)
        @logger.info("Task marked as #{status}: #{task['id']} - #{task['description']}")
      else
        @logger.warn("Invalid status: #{status}. Valid statuses are: #{VALID_STATUSES.join(', ')}")
      end
    else
      @logger.warn("Task not found with id: #{id}")
    end
  end

  def list_tasks(filter = nil)
    filtered_tasks = filter ? @tasks.select { |t| t['status'] == filter } : @tasks

    if filtered_tasks.empty?
      @logger.info("No tasks found.")
    else
      filtered_tasks.each do |task|
        @logger.info("#{task['id']} - [#{task['status']}] #{task['description']}")
      end
    end
  end

  def find_task(id)
    @tasks.find { |t| t['id'].to_s == id }
  end
end

TaskTracker.new.run(ARGV) if __FILE__ == $PROGRAM_NAME
