# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20_210_303_004_413) do
  create_table 'attributes', force: :cascade do |t|
    t.string 'task'
    t.string 'variable'
    t.string 'value'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.integer 'demarche_id', null: false
    t.integer 'dossier'
    t.index ['demarche_id'], name: 'index_attributes_on_demarche_id'
    t.index ['dossier'], name: 'index_attributes_on_dossier'
    t.index ['variable'], name: 'index_attributes_on_variable'
  end

  create_table 'delayed_jobs', force: :cascade do |t|
    t.integer 'priority', default: 0, null: false
    t.integer 'attempts', default: 0, null: false
    t.text 'handler', null: false
    t.text 'last_error'
    t.datetime 'run_at'
    t.datetime 'locked_at'
    t.datetime 'failed_at'
    t.string 'locked_by'
    t.string 'queue'
    t.datetime 'created_at', precision: 6
    t.datetime 'updated_at', precision: 6
    t.string 'cron'
    t.index %w[priority run_at], name: 'delayed_jobs_priority'
  end

  create_table 'demarches', force: :cascade do |t|
    t.string 'name'
    t.datetime 'queried_at'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
  end

  create_table 'job_tasks', force: :cascade do |t|
    t.integer 'demarche_id', null: false
    t.string 'name'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['demarche_id'], name: 'index_job_tasks_on_demarche_id'
  end

  create_table 'syncs', force: :cascade do |t|
    t.string 'job'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
  end

  create_table 'task_executions', force: :cascade do |t|
    t.integer 'job_task_id', null: false
    t.integer 'dossier'
    t.boolean 'failed'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.float 'version'
    t.index ['dossier'], name: 'index_task_executions_on_dossier'
    t.index ['failed'], name: 'index_task_executions_on_failed'
    t.index ['job_task_id'], name: 'index_task_executions_on_job_task_id'
  end

  add_foreign_key 'attributes', 'demarches', column: 'demarche_id'
  add_foreign_key 'job_tasks', 'demarches', column: 'demarche_id'
  add_foreign_key 'task_executions', 'job_tasks'
end
