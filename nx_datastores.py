#!/usr/bin/env python

import json
from snap import common
from mercury.dataload import DataStore
from mercury.mlog import mlog, mlog_err
import uuid
from collections import namedtuple
from datetime import datetime
from nx_utils import convert_to_timestamp
from sqlalchemy.dialects import postgresql


class ObjectFactory(object):
    @classmethod
    def create_db_object(cls, table_name, db_svc, **kwargs):
        DbObject = getattr(db_svc.Base.classes, table_name)
        return DbObject(**kwargs)


class MongoDatastore(DataStore):
    def __init__(self, service_object_registry, *channels, **kwargs):
        super().__init__(service_object_registry, *channels, **kwargs)


    def write_reddit_doc(self, record, mongo_db_svc):        
        db = mongo_db_svc.get_database()
        collection = db['reddit_posts']
        id = collection.insert_one(record).inserted_id
        return str(id)


    def write(self, records, **write_params):

        mongo_svc = self.service_object_registry.lookup('mongo')
        
        for raw_rec in records:
            rec = json.loads(raw_rec)
            try:
                output_record = rec['data']
                newid =  self.write_reddit_doc(output_record, mongo_svc)
                
                output_record.pop('_id')
                output_record['mongo_id'] = newid
                print(json.dumps(output_record))

            except Exception as err:
                mlog_err(
                    err, issue=f"Error ingesting Mongo document.", record=rec
                )


ValueBin = namedtuple('ValueBin', 'min max name')

class PostgresDatastore(DataStore):
    def __init__(self, service_object_registry, *channels, **kwargs):
        super().__init__(service_object_registry, *channels, **kwargs)

        self.bins = []
        self.bins.append(ValueBin(min=0, max=9, name='0-9'))
        self.bins.append(ValueBin(min=10, max=49, name='10-49'))
        self.bins.append(ValueBin(min=50, max=99, name='50-99'))
        self.bins.append(ValueBin(min=100, max=999, name='100-999'))
        self.bins.append(ValueBin(min=1000, max=None, name='>1000'))

        
    def get_binned_value(self, value):

        for bin in self.bins:
            if value >= bin.min:
                if bin.max is None:
                    return bin.name
                elif value <= bin.max:
                    return bin.name


    def prepare_binned_values(self, record):

        olap = self.service_object_registry.lookup('olap')

        dim_upvotes_bin_name = self.get_binned_value(record['num_upvotes'])
        dim_comments_bin_name = self.get_binned_value(record['num_comments'])
        dim_crossposts_bin_name = self.get_binned_value(record['num_crossposts'])

        bvalues = {
            'dim_upvotes_bin_id': olap.dim_id_for_value('dim_upvotes_bin', dim_upvotes_bin_name),
            'dim_comments_bin_id': olap.dim_id_for_value('dim_comments_bin', dim_comments_bin_name),
            'dim_xposts_bin_id': olap.dim_id_for_value('dim_xposts_bin', dim_crossposts_bin_name)
        }
        
        return bvalues
    

    def prepare_date_time_values(self, int_timestamp_seconds):

        olap = self.service_object_registry.lookup('olap')

        dt = datetime.fromtimestamp(int_timestamp_seconds)
        date_time_string = str(dt)
        
        # This will give us the format: '2023-10-31 21:15:30'

        datetime_tokens = date_time_string.split(' ')
        date_part = datetime_tokens[0]
        time_part = datetime_tokens[1]

        date_tokens = date_part.split('-')
        date_year = date_tokens[0]
        date_month = date_tokens[1]
        date_day = date_tokens[2]

        time_tokens = time_part.split(':')
        time_hour = time_tokens[0]
        time_minute = time_tokens[1]

        day_id = olap.dim_id_for_value('dim_date_day', int(date_day))
        month_id = olap.dim_id_for_value('dim_date_month', int(date_month))
        year_id = olap.dim_id_for_value('dim_date_year', int(date_year))

        hour_id = olap.dim_id_for_value('dim_time_hour', int(time_hour))
        minute_id = olap.dim_id_for_value('dim_time_minute', int(time_minute))

        return {
            'dim_date_month_id': month_id,
            'dim_date_day_id': day_id,
            'dim_date_year_id': year_id,
            'dim_time_hour_id': hour_id,
            'dim_time_minute_id': minute_id
        }


    def write_reddit_data(self, record, db_service, **write_params):
        
        new_id = None
        with db_service.txn_scope() as session:  

            dt = datetime.fromtimestamp(record['created_utc'])
            
            post_data = {
                'id': str(uuid.uuid4()),
                'mdb_object_id': record['mongo_id'],
                'reddit_id': record['id'],
                'subreddit_id': record['subreddit_id'],
                'subreddit_name': record['subreddit'],
                'author_name': record['author'],
                'num_upvotes': record['ups'],
                'num_comments': record['num_comments'],
                'num_crossposts': record['num_crossposts'],
                'score': record['score'],
                'event_timestamp': dt
            }

            post_data.update(self.prepare_date_time_values(record['created_utc']))
            post_data.update(self.prepare_binned_values(post_data))

            new_post = ObjectFactory.create_db_object(
                "fact_post", db_service, **post_data
            )
            
            session.add(new_post)
            session.flush()            
            new_id = new_post.id

        return new_id
    

    def write(self, records, **write_params):
        postgres_svc = self.service_object_registry.lookup("postgres")
        record_type = write_params.get("record_type", "NULL")
        for raw_rec in records:
            rec = json.loads(raw_rec)
            if record_type == "reddit_post":
                try:
                    id = self.write_reddit_data(rec, postgres_svc)
                    print(id)

                except Exception as err:
                    mlog_err(
                        err, issue=f"Error ingesting {record_type} record.", record=rec
                    )

            else:
                mlog_err(
                    Exception(
                        f"Unrecognized or unspecified record type {record_type}. Please check your ngst command parameters."
                    )
                )
